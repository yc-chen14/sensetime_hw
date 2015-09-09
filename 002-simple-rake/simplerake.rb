require 'optparse'
require 'logger'
require 'ostruct'

class SimpleRake

  def initialize options
    
    @mode = options[:mode]
    @filename = nil
    @input_task = nil
    @task_information_hash = {}
    @execution_sequence = []

    $default_task = nil

    $task_information_array = []
    
    $descriptor = nil
    $task = nil
    $cmd = nil
    $pre_task = nil

    @logger = Logger.new $stderr

    # File name is valid?
    if ARGV.empty?
      fail "Could not get a file name"
    elsif File.file?(ARGV[0]) && File.readable?(ARGV[0])
      @filename = ARGV[0]
      @input_task = ARGV[1].to_sym
    else
      fail "File does not exist"
    end

  end

  def run
    
    get_task_information @filename

    if @mode == 'list_tasks'
      list_tasks
      exit
    end

    if @input_task == nil && $default_task == nil
      fail "No default task, aborted"
    end

    @input_task ||= @default_task
    @task_information_hash = array_to_hash $task_information_array
    get_execution_sequence @input_task
    @execution_sequence.reverse!
    execute

  end

  def get_task_information filename
    load filename
  end

  def list_tasks
    $task_information_array.each do |element|
      puts "#{element[:task]}                    # #{element[:descriptor]}"
    end
  end

  def array_to_hash array
    hash = {}
    array.each do |element|
      hash[element[:task]] = element
    end
    return hash
  end

  def get_execution_sequence task
    if @task_information_hash[task]
      @execution_sequence << task
      get_pre_task task
    else
      fail 'Could not find the task.'
    end
  end

  def get_pre_task task
    if @task_information_hash[task][:pre_task] == nil
      return
    else
      pre_task = @task_information_hash[task][:pre_task]
      @execution_sequence << pre_task
      if pre_task.is_a?(Symbol)
        get_pre_task pre_task
      else
        pre_task.each do |t|
          get_pre_task t
        end
      end
    end
  end

  def execute
    implemented_task = []
    @execution_sequence.each do |element|
      if element.is_a?(Symbol)
        if implemented_task.include?(element)
          next
        else
          puts @task_information_hash[element][:descriptor]
          implemented_task << element
        end
      else
        element.each do |e|
          if implemented_task.include?(e)
            next
          else
            puts @task_information_hash[e][:descriptor]
            implemented_task << e
          end
        end
      end
    end
  end

end

def desc descriptor
  $descriptor = descriptor
end

def task task

  information = {:descriptor => nil, :task => nil, :cmd => nil, :pre_task => nil}
  if task.is_a?(Hash)
    if task.first[0] == :default
      $default_task = task.first[1]
      return
    else
      information[:task] = task.first[0]
      information[:pre_task] = task.first[1]
    end
  else
    information[:task] = task
  end
  information[:descriptor] = $descriptor
  $descriptor = nil
  #puts information
  $task_information_array << information
end

def sh cmd
  $task_information_array[-1][:cmd] = cmd
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

