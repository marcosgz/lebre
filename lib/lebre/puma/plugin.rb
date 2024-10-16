require "puma/plugin"

Puma::Plugin.create do
  attr_reader :puma_pid, :lebre_pid, :log_writer, :lebre_supervisor

  def start(launcher)
    @log_writer = launcher.log_writer
    @puma_pid = $$

    in_background do
      monitor_lebre
    end

    launcher.events.on_booted do
      @lebre_pid = fork do
        Thread.new { monitor_puma }
        Lebre::Supervisor.start
      end
    end

    launcher.events.on_stopped { stop_lebre }
    launcher.events.on_restart { stop_lebre }
  end

  private

  def stop_lebre
    Process.waitpid(lebre_pid, Process::WNOHANG)
    log "Stopping Lebre..."
    Process.kill(:INT, lebre_pid) if lebre_pid
    Process.wait(lebre_pid)
  rescue Errno::ECHILD, Errno::ESRCH
  end

  def monitor_puma
    monitor(:puma_dead?, "Detected Puma has gone away, stopping Lebre...")
  end

  def monitor_lebre
    monitor(:lebre_dead?, "Detected Lebre has gone away, stopping Puma...")
  end

  def monitor(process_dead, message)
    loop do
      if send(process_dead)
        log message
        Process.kill(:INT, $$)
        break
      end
      sleep 2
    end
  end

  def lebre_dead?
    if lebre_started?
      Process.waitpid(lebre_pid, Process::WNOHANG)
    end
    false
  rescue Errno::ECHILD, Errno::ESRCH
    true
  end

  def lebre_started?
    !lebre_pid.nil?
  end

  def puma_dead?
    Process.ppid != puma_pid
  end

  def log(*args)
    log_writer.log(*args)
  end
end
