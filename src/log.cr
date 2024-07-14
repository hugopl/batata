require "colorize"
require "log"

private struct LogFormat
  extend Log::Formatter

  def self.format(entry : Log::Entry, io : IO)
    # Timestamp
    io << entry.timestamp.hour << ':' << entry.timestamp.minute << " "

    # Colored severity
    (6 - entry.severity.label.size).times do
      io << ' '
    end
    color = case entry.severity
            when .error?  then Colorize::ColorANSI::Red
            when .fatal?  then Colorize::ColorANSI::Red
            when .notice? then Colorize::ColorANSI::Blue
            when .info?   then Colorize::ColorANSI::Green
            when .warn?   then Colorize::ColorANSI::Yellow
            when .trace?  then Colorize::ColorANSI::Cyan
            else
              Colorize::ColorANSI::Default
            end
    entry.severity.label.colorize(color).to_s(io)
    io << ' ' << entry.source.colorize.cyan unless entry.source.empty?
    # Message
    io << ": "
    exception = entry.exception
    if exception && entry.severity > Log::Severity::Warn && entry.exception
      exception.inspect_with_backtrace(io)
    else
      io << entry.message
    end
  end
end

def setup_logger(log_level : String?)
  level = log_level ? Log::Severity.parse(log_level) : Log::Severity::Info

  log_io = begin
    {% if flag?(:release) %}
      File.open(File.join(Dir.tempdir, "batata.log"), "a")
    {% else %}
      STDOUT
    {% end %}
  end
  backend = Log::IOBackend.new(io: log_io, formatter: LogFormat, dispatcher: :direct)
  Log.setup(level, backend)
  Log.info { "Batata v#{VERSION} started at #{Time.local}, pid: #{Process.pid}, log level: #{level}" }
end
