class Command
  def execute(calculator, *args)
    raise NotImplementedError
  end
end

class PlusCommand < Command
  def execute(calculator, a, b)
    a + b
  end
end

class MinusCommand < Command
  def execute(calculator, a, b)
    a - b
  end
end

class MultiplyCommand < Command
  def execute(calculator, a, b)
    a * b
  end
end

class DivideCommand < Command
  def execute(calculator, a, b)
    raise "Division by zero" if b == 0
    a.to_f / b
  end
end

class ModCommand < Command
  def execute(calculator, a, b)
    raise "Division by zero" if b == 0
    raise "mod only for integers" unless calculator.integer?(a) && calculator.integer?(b)

    a.to_i % b.to_i
  end
end

class PowCommand < Command
  def execute(calculator, a, b)
    a**b
  end
end

class NegCommand < Command
  def execute(calculator, a)
    -a
  end
end

class SqrtCommand < Command
  def execute(calculator, a)
    raise "Negative sqrt" if a < 0
    Math.sqrt(a)
  end
end

class SinCommand < Command
  def execute(calculator, a)
    Math.sin(a)
  end
end

class CosCommand < Command
  def execute(calculator, a)
    Math.cos(a)
  end
end

class TanCommand < Command
  def execute(calculator, a)
    Math.tan(a)
  end
end

class CtanCommand < Command
  def execute(calculator, a)
    t = Math.tan(a)
    raise "ctan undefined" if t == 0

    1.0 / t
  end
end

class ExpCommand < Command
  def execute(calculator, a)
    Math.exp(a)
  end
end

class LnCommand < Command
  def execute(calculator, a)
    raise "ln undefined" if a <= 0
    Math.log(a)
  end
end

class FactorialCommand < Command
  def execute(calculator, a)
    calculator.factorial(a)
  end
end

class PushCommand < Command
  def execute(calculator)
    raise "Nothing to push" if calculator.current_result.nil?

    calculator.stack << calculator.current_result
    calculator.history << "push #{calculator.format_number(calculator.current_result)}"

    calculator.current_result
  end
end

class PopCommand < Command
  def execute(calculator)
    raise "Stack is empty" if calculator.stack.empty?

    value = calculator.stack.pop
    calculator.current_result = value
    calculator.history << "pop = #{calculator.format_number(value)}"

    value
  end
end

class MemoryWriteCommand < Command
  def execute(calculator)
    raise "Nothing to write" if calculator.current_result.nil?

    calculator.memory = calculator.current_result
    calculator.history << "mw #{calculator.format_number(calculator.memory)}"

    calculator.memory
  end
end

class MemoryReadCommand < Command
  def execute(calculator)
    calculator.current_result = calculator.memory
    calculator.history << "mr = #{calculator.format_number(calculator.memory)}"

    calculator.current_result
  end
end

class HistoryCommand < Command
  def execute(calculator)
    if calculator.history.empty?
      puts "History is empty"
    else
      calculator.history.each_with_index do |item, index|
        puts "#{index + 1}. #{item}"
      end
    end

    nil
  end
end

class PrimesCommand < Command
  def execute(calculator)
    raise "No left operand for primes" if calculator.current_result.nil?
    raise "Operator already pending" if calculator.pending_binary_op

    calculator.pending_primes = true
    calculator.primes_start = calculator.current_result

    "primes"
  end
end

class Calculator
  attr_accessor :memory,
                :history,
                :current_result,
                :pending_binary_op,
                :waiting_for_number,
                :stack,
                :pending_primes,
                :primes_start

  def initialize
    @memory = 0.0
    @history = []
    @current_result = nil
    @pending_binary_op = nil
    @waiting_for_number = false

    @stack = []
    @pending_primes = false
    @primes_start = nil

    @operations = {
      "+" => PlusCommand.new,
      "-" => MinusCommand.new,
      "*" => MultiplyCommand.new,
      "/" => DivideCommand.new,
      "mod" => ModCommand.new,
      "pow" => PowCommand.new,

      "--" => NegCommand.new,
      "sqrt" => SqrtCommand.new,
      "sin" => SinCommand.new,
      "cos" => CosCommand.new,
      "tan" => TanCommand.new,
      "ctan" => CtanCommand.new,
      "exp" => ExpCommand.new,
      "ln" => LnCommand.new,
      "!" => FactorialCommand.new,

      "push" => PushCommand.new,
      "pop" => PopCommand.new,
      "mw" => MemoryWriteCommand.new,
      "mr" => MemoryReadCommand.new,
      "history" => HistoryCommand.new,
      "primes" => PrimesCommand.new
    }
  end

  def start
    puts "Calculator has started"

    loop do
      input = gets&.strip
      break if input.nil?

      cmd = input.downcase

      begin
        break if cmd == "exit"

        if service_command?(cmd)
          result = @operations[cmd].execute(self)
          puts format_number(result) unless result.nil?
        else
          process_input(input)
        end
      rescue
        reset_chain_state
        puts "Error"
      end
    end
  end

  def integer?(x)
    x % 1 == 0
  end

  def factorial(x)
    raise "Invalid factorial" if x < 0 || !integer?(x)

    (1..x.to_i).reduce(1, :*)
  end

  def format_number(num)
    if num.is_a?(Numeric) && num.finite? && num % 1 == 0
      num.to_i.to_s
    else
      num.to_s
    end
  end

  private

  def service_command?(cmd)
    ["push", "pop", "mw", "mr", "history", "primes"].include?(cmd)
  end

  def process_input(input)
    if expression_input?(input)
      result = evaluate_expression(input)
      @current_result = result
      @history << "#{input} = #{format_number(result)}"
      reset_chain_state
      puts format_number(result)
      return
    end

    if number?(input)
      process_number(input.to_f)
      return
    end

    if unary_operator?(input)
      process_unary(input)
      return
    end

    if binary_operator?(input)
      process_binary(input)
      return
    end

    raise "Invalid input"
  end

  def process_number(num)
    if @pending_primes
      process_primes_range(num)
      return
    end

    if @current_result.nil?
      @current_result = num
      @history << format_number(num)
      puts format_number(@current_result)
    elsif @pending_binary_op
      left = @current_result
      op = @pending_binary_op

      result = @operations[op].execute(self, left, num)

      @current_result = result
      @history << "#{format_number(left)} #{op} #{format_number(num)} = #{format_number(result)}"
      @pending_binary_op = nil
      @waiting_for_number = false

      puts format_number(@current_result)
    else
      @current_result = num
      @history << format_number(num)
      puts format_number(@current_result)
    end
  end

  def process_binary(op)
    raise "Missing left operand" if @current_result.nil?
    raise "Two operators in a row" if @pending_binary_op

    @pending_binary_op = op
    @waiting_for_number = true

    puts op
  end

  def process_unary(op)
    raise "No operand" if @current_result.nil?

    before = @current_result
    result = @operations[op].execute(self, before)

    @current_result = result
    @history << "#{op} #{format_number(before)} = #{format_number(result)}"

    puts format_number(@current_result)
  end

  def reset_chain_state
    @pending_binary_op = nil
    @waiting_for_number = false
    @pending_primes = false
    @primes_start = nil
  end

  def binary_operator?(input)
    ["+", "-", "*", "/", "mod", "pow"].include?(input)
  end

  def unary_operator?(input)
    ["--", "sqrt", "sin", "cos", "tan", "ctan", "exp", "ln", "!"].include?(input)
  end

  def expression_input?(input)
    input.include?("(") || input.include?(")") || input.include?(" ")
  end

  def number?(input)
    !!(input =~ /^-?\d+(\.\d+)?$/)
  end

  def process_primes_range(limit)
    raise "Invalid primes range" unless integer?(@primes_start) && integer?(limit)

    start_num = @primes_start.to_i
    end_num = limit.to_i

    raise "Invalid primes range" if end_num <= start_num

    primes = find_primes_in_range(start_num + 1, end_num)

    raise "No primes found" if primes.empty?

    primes.each do |prime|
      @stack << prime
    end

    @current_result = primes.last
    @history << "primes #{start_num}..#{end_num} => #{primes.join(', ')}"

    @pending_primes = false
    @primes_start = nil

    puts format_number(@current_result)
  end

  def find_primes_in_range(from, to)
    result = []

    (from..to).each do |num|
      result << num if prime?(num)
    end

    result
  end

  def prime?(n)
    return false if n < 2
    return true if n == 2
    return false if n.even?

    i = 3
    while i * i <= n
      return false if n % i == 0

      i += 2
    end

    true
  end

  def evaluate_expression(input)
    tokens = tokenize(input)
    rpn = to_rpn(tokens)
    eval_rpn(rpn)
  end

  def tokenize(input)
    s = input.gsub(/\s+/, "")
    tokens = []
    i = 0

    while i < s.length
      ch = s[i]

      if ch =~ /\d/ || ch == "."
        num = ""

        while i < s.length && s[i] =~ /[\d.]/
          num << s[i]
          i += 1
        end

        raise "Invalid number" if num.count(".") > 1

        tokens << [:number, num.to_f]
        next
      end

      if ch =~ /[A-Za-z]/
        word = ""

        while i < s.length && s[i] =~ /[A-Za-z]/
          word << s[i]
          i += 1
        end

        case word
        when "mod", "pow"
          tokens << [:operator, word]
        when "sqrt", "sin", "cos", "tan", "ctan", "exp", "ln"
          tokens << [:function, word]
        when "mr"
          tokens << [:number, @memory]
        else
          raise "Unknown identifier"
        end

        next
      end

      case ch
      when "+"
        tokens << [:operator, "+"]
      when "-"
        tokens << [:operator, "-"]
      when "*"
        tokens << [:operator, "*"]
      when "/"
        tokens << [:operator, "/"]
      when "!"
        tokens << [:operator, "!"]
      when "("
        tokens << [:lparen, "("]
      when ")"
        tokens << [:rparen, ")"]
      else
        raise "Invalid symbol"
      end

      i += 1
    end

    mark_unary_minus(tokens)
  end

  def mark_unary_minus(tokens)
    result = []

    tokens.each_with_index do |token, i|
      type, value = token

      if type == :operator && value == "-"
        if i == 0 || [:operator, :lparen].include?(tokens[i - 1][0]) || tokens[i - 1][0] == :function
          result << [:function, "neg"]
        else
          result << token
        end
      else
        result << token
      end
    end

    result
  end

  def precedence(token)
    type, value = token

    return 5 if type == :operator && value == "!"
    return 4 if type == :function
    return 3 if type == :operator && ["*", "/", "mod"].include?(value)
    return 2 if type == :operator && ["+", "-"].include?(value)
    return 1 if type == :operator && value == "pow"

    0
  end

  def right_associative?(token)
    type, value = token

    return true if type == :operator && value == "pow"
    return true if type == :function

    false
  end

  def to_rpn(tokens)
    output = []
    stack = []

    tokens.each do |token|
      type, = token

      case type
      when :number
        output << token
      when :function
        stack << token
      when :operator
        while !stack.empty? &&
              (
                stack.last[0] == :function ||
                (
                  stack.last[0] == :operator &&
                  (
                    precedence(stack.last) > precedence(token) ||
                    precedence(stack.last) == precedence(token) && !right_associative?(token)
                  )
                )
              )
          output << stack.pop
        end

        stack << token
      when :lparen
        stack << token
      when :rparen
        while !stack.empty? && stack.last[0] != :lparen
          output << stack.pop
        end

        raise "Mismatched parentheses" if stack.empty?

        stack.pop

        output << stack.pop if !stack.empty? && stack.last[0] == :function
      end
    end

    until stack.empty?
      raise "Mismatched parentheses" if [:lparen, :rparen].include?(stack.last[0])

      output << stack.pop
    end

    output
  end

  def eval_rpn(rpn)
    stack = []

    rpn.each do |token|
      type, value = token

      case type
      when :number
        stack << value
      when :operator
        if value == "!"
          a = stack.pop
          raise "Missing operand" if a.nil?

          stack << @operations["!"].execute(self, a)
        else
          b = stack.pop
          a = stack.pop

          raise "Missing operands" if a.nil? || b.nil?

          stack << @operations[value].execute(self, a, b)
        end
      when :function
        a = stack.pop
        raise "Missing operand" if a.nil?

        if value == "neg"
          stack << @operations["--"].execute(self, a)
        else
          stack << @operations[value].execute(self, a)
        end
      end
    end

    raise "Invalid expression" unless stack.size == 1

    stack[0]
  end
end

Calculator.new.start