# frozen_string_literal: true

class Lebre::LogSubscriber < ActiveSupport::LogSubscriber
  def start_process(event)
    process = event.payload[:process]

    attributes = {
      pid: process.pid,
      hostname: process.hostname,
      process_id: process.process_id,
      name: process.name
    }.merge(process.metadata)

    info formatted_event(event, action: "Started #{process.kind}", **attributes)
  end

  def shutdown_process(event)
    process = event.payload[:process]

    attributes = {
      pid: process.pid,
      hostname: process.hostname,
      process_id: process.process_id,
      name: process.name
    }.merge(process.metadata)

    info formatted_event(event, action: "Shutdown #{process.kind}", **attributes)
  end

  def register_process(event)
    process_kind = event.payload[:kind]
    attributes = event.payload.slice(:pid, :hostname, :process_id, :name)

    if (error = event.payload[:error])
      warn formatted_event(event, action: "Error registering #{process_kind}", **attributes.merge(error: formatted_error(error)))
    else
      debug formatted_event(event, action: "Register #{process_kind}", **attributes)
    end
  end

  def deregister_process(event)
    process = event.payload[:process]

    attributes = {
      process_id: process.id,
      pid: process.pid,
      hostname: process.hostname,
      name: process.name,
      last_heartbeat_at: process.last_heartbeat_at&.strftime("%Y-%m-%d %H:%M:%S"),
      claimed_size: event.payload[:claimed_size],
      pruned: event.payload[:pruned]
    }

    if (error = event.payload[:error])
      warn formatted_event(event, action: "Error deregistering #{process.kind}", **attributes.merge(error: formatted_error(error)))
    else
      debug formatted_event(event, action: "Deregister #{process.kind}", **attributes)
    end
  end

  def prune_processes(event)
    debug formatted_event(event, action: "Prune dead processes", **event.payload.slice(:size))
  end

  def thread_error(event)
    error formatted_event(event, action: "Error in thread", error: formatted_error(event.payload[:error]))
  end

  def graceful_termination(event)
    attributes = event.payload.slice(:process_id, :supervisor_pid, :supervised_processes)

    if event.payload[:shutdown_timeout_exceeded]
      warn formatted_event(event, action: "Supervisor wasn't terminated gracefully - shutdown timeout exceeded", **attributes)
    else
      info formatted_event(event, action: "Supervisor terminated gracefully", **attributes)
    end
  end

  def immediate_termination(event)
    info formatted_event(event, action: "Supervisor terminated immediately", **event.payload.slice(:process_id, :supervisor_pid, :supervised_processes))
  end

  def unhandled_signal_error(event)
    error formatted_event(event, action: "Received unhandled signal", **event.payload.slice(:signal))
  end

  def replace_fork(event)
    status = event.payload[:status]
    attributes = event.payload.slice(:pid).merge \
      status: status.exitstatus || "no exit status set",
      pid_from_status: status.pid,
      signaled: status.signaled?,
      stopsig: status.stopsig,
      termsig: status.termsig

    if (replaced_fork = event.payload[:fork])
      info formatted_event(event, action: "Replaced terminated #{replaced_fork.kind}", **attributes.merge(hostname: replaced_fork.hostname, name: replaced_fork.name))
    else
      warn formatted_event(event, action: "Tried to replace forked process but it had already died", **attributes)
    end
  end

  private

  def formatted_event(event, action:, **attributes)
    "Lebre-#{Lebre::VERSION} #{action} (#{event.duration.round(1)}ms)  #{formatted_attributes(**attributes)}"
  end

  def formatted_attributes(**attributes)
    attributes.map { |attr, value| "#{attr}: #{value.inspect}" }.join(", ")
  end

  def formatted_error(error)
    [error.class, error.message].compact.join(" ")
  end

  def logger
    Lebre.logger
  end
end
