# frozen_string_literal: true

module Lebre
  class Process
    class NotFoundError < RuntimeError
      def initialize(id)
        super("Process with id #{id} not found")
      end
    end

    ATTRIBUTES = %i[id name pid hostname kind last_heartbeat_at supervisor_id].freeze
    MEMORY_GRABBER = case RUBY_PLATFORM
    when /linux/
      ->(pid) {
        IO.readlines("/proc/#{$$}/status").each do |line|
          next unless line.start_with?("VmRSS:")
          break line.split[1].to_i
        end
      }
    when /darwin|bsd/
      ->(pid) {
        `ps -o pid,rss -p #{pid}`.lines.last.split.last.to_i
      }
    else
      ->(pid) { 0 }
    end

    class << self
      def register(**attributes)
        attributes[:id] ||= SecureRandom.uuid
        Lebre.instrument :register_process, **attributes do |payload|
          new(**attributes).tap do |process|
            ProcessRegistry.instance.add(process)
            payload[:process_id] = process.id
          end
        rescue Exception => error # rubocop:disable Lint/RescueException
          payload[:error] = error
          raise
        end
      end

      def prune(excluding: nil)
        Lebre.instrument :prune_processes, size: 0 do |payload|
          arr = prunable
          arr.delete(excluding) if excluding
          payload[:size] = arr.size

          arr.each(&:prune)
        end
      end

      def prunable
        ProcessRegistry.instance.all.select do |process|
          process.last_heartbeat_at && process.last_heartbeat_at < Time.now - Lebre.config.process_alive_threshold
        end
      end
    end

    attr_reader :attributes

    def initialize(**attributes)
      @attributes = attributes
      @attributes[:id] ||= SecureRandom.uuid
    end

    ATTRIBUTES.each do |attribute|
      define_method(attribute) { attributes[attribute] }
    end

    def last_heartbeat_at
      attributes[:last_heartbeat_at]
    end

    def rss_memory
      MEMORY_GRABBER.call(pid)
    end

    def heartbeat
      now = Time.now
      Lebre.instrument :heartbeat_process, process: self, rss_memory: 0, last_heartbeat_at: now do |payload|
        ProcessRegistry.instance.find(id) # ensure process is still registered

        update_attributes(last_heartbeat_at: now)
        payload[:rss_memory] = rss_memory
      rescue Exception => error # rubocop:disable Lint/RescueException
        payload[:error] = error
        raise
      end
    end

    def update_attributes(new_attributes)
      @attributes = @attributes.merge(new_attributes)
    end

    def destroy!
      Lebre.instrument :destroy_process, process: self do |payload|
        ProcessRegistry.instance.delete(self)
      rescue Exception => error # rubocop:disable Lint/RescueException
        payload[:error] = error
        raise
      end
    end

    def deregister(pruned: false)
      Lebre.instrument :deregister_process, process: self, pruned: pruned do |payload|
        destroy!

        unless supervised? || pruned
          supervisees.each(&:deregister)
        end
      rescue Exception => error # rubocop:disable Lint/RescueException
        payload[:error] = error
        raise
      end
    end

    def prune
      # error = Lebre::Processes::ProcessPrunedError.new(last_heartbeat_at)
      # fail_all_claimed_executions_with(error)

      deregister(pruned: true)
    end

    def supervised?
      !attributes[:supervisor_id].nil?
    end

    def eql?(other)
      other.is_a?(self.class) && other.id == id && other.pid == pid
    end
    alias_method :==, :eql?

    private

    def supervisees
      ProcessRegistry.instance.all.select { |process| process.supervisor_id == id }
    end
  end
end
