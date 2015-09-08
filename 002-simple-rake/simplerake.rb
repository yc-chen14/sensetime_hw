require 'optparse'
require 'logger'
require 'ostruct'

class SimpleRake

  def initialize options
    
    @mode = options[:mode]
    @filename = nil
    @task = nil
    @default_segment = []
    @task_segments = []
    @task_list = []
    @default_task = nil
    @task_information = {}
    @execution_sequence = []
    @execution_sequence_final = []
    @logger = Logger.new $stderr

    if ARGV.empty?
      fail "Could not get a file name"
    elsif File.file?(ARGV[0]) && File.readable?(ARGV[0])
      @filename = ARGV[0]
      @task = ARGV[1]
    else
      fail "File does not exist"
    end

  end

  def run

    # Divide the file into multiple modules
    file_segment

    # If default task exist, extract it.
    if @default_segment.size > 0
      default_task_extract
    end
   
    # Get task informations: task name, task, cmd and pre_task
    @task_segments.each do |segment|
      information = segment_analysize segment
      task = information[:task]
      @task_list << task
      @task_information[task.to_sym] = information
    end

    if @mode == 'list_tasks'
      task_list
      exit
    end

    if @task == nil && @default_segment.size == 0
      fail "No default task, aborted"
    end

    @task ||= @default_task
    get_execution_sequence @task
    @execution_sequence.reverse!
    @execution_sequence_final = get_single_task_sequence @execution_sequence

    if @mode == nil
      execute
    end
  end

  # Divide the file into multiple modules
  def file_segment
    file = File.open(@filename)
    segment = []
    file.each_line do |line|
      if (/^#/ =~ line) || (/^\s$/ =~ line)
        next
      elsif /default/ =~ line
        segment << line
        @default_segment << segment
        segment = []
      elsif /^end$/ =~ line
        @task_segments << segment
        segment = []
      else
        segment << line
      end
    end
    file.close
  end

  # If default task exist, extract it.
  def default_task_extract
    if /=>\s:(.*)/ =~ @default_segment[0][0]
      @default_task = $1
    end
  end

  # Get task information
  def segment_analysize segment
    information = {:name => nil, :task => nil, :cmd => nil, :pre_task => nil}
    segment.each do |line|
      if /desc\s'(.*)'/ =~ line
        information[:name] = $1
      end
      if /task\s:(.*)\s/ =~ line
        information[:task] = $1
      end
      if /sh\s'(.*)'/ =~ line
        information[:cmd] = $1
      end
    end
    if /(.*)\s=>\s(.*)\sdo/ =~ information[:task]
      information[:task] = $1
      information[:pre_task] = $2
    elsif /(.*)\sdo/ =~ information[:task]
      information[:task] = $1
    end
    if information[:pre_task]
      information[:pre_task].gsub!(':','').gsub!(',','')
      information[:pre_task].delete!('[')
      information[:pre_task].delete!(']')
    end
    puts information
    return information
  end

  def get_execution_sequence task
    if @task_information[task.to_sym]
      @execution_sequence << task
      get_pre_task task
    else
      fail 'Could not find the task.'
    end 
  end

  def get_pre_task task
    if @task_information[task.to_sym][:pre_task] == nil
      return
    else
      pre_task = @task_information[task.to_sym][:pre_task]
      @execution_sequence << pre_task
      pre_task = pre_task.split(' ')
      pre_task.each do |t|
        get_pre_task t
      end
    end
  end

  def get_single_task_sequence sequence
    single_task_sequence = []
    sequence.each do |element|
      element = element.split(' ')
      element.each do |single_task|
        if single_task_sequence.include?single_task
          next
        else
          single_task_sequence << single_task
        end
      end
    end
    return single_task_sequence
  end

  def execute
    @execution_sequence_final.each do |task|
      cmd = @task_information[task.to_sym][:cmd]
      system cmd
    end
  end

  def task_list
    @task_list.each do |task|
      puts "#{@task_information[task.to_sym][:task]}          # #{@task_information[task.to_sym][:name]}"
    end
  end

end


if __FILE__ == $0
  options = {}
  options[:mode] = nil
  OptionParser.new do |opts|
    opts.banner = "Usage: #{$0} [options] srake_file [task]"

    opts.on("-T","list task") do
      options[:mode] = 'list_tasks'
    end

    opts.on_tail("-h","print help") do
      puts opts
      exit
    end
  end.parse!

simplerake = SimpleRake.new options
simplerake.run
end
