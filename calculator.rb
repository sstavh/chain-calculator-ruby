class Calculator
  def initialize
    @memory = 0.0
    @history = []
    @current_result = nil
    @pending_binary_op = nil
    @waiting_for_number = false
    @expression_mode = false

    @stack = []
    @pending_primes = false
    @primes_start = nil
  end

  def start
    puts "Calculator has started"

    loop do
      input = gets&.strip
      break if input.nil?

      cmd = input.downcase

      begin
        case cmd
        when "exit"
          break
        when "history"
          show_history
        when "mw"
          memory_write
        when "mr"
          memory_read
        when "push"
          push_stack
        when "pop"
          pop_stack
        when "primes"
          start_primes
        else
          process_input(input)
        end
      rescue
        reset_chain_state
        puts "Error"
      end
    end
  end

  private

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
      @history << "#{format_number(num)}"
      puts format_number(@current_result)
    elsif @pending_binary_op
      left = @current_result
      op = @pending_binary_op
      result = apply_binary(op, left, num)
      @current_result = result
      @history << "#{format_number(left)} #{op} #{format_number(num)} = #{format_number(result)}"
      @pending_binary_op = nil
      @waiting_for_number = false
      puts format_number(@current_result)
    else
      @current_result = num
      @history << "#{format_number(num)}"
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
    result = apply_unary(op, @current_result)
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

  def memory_write
    raise "Nothing to write" if @current_result.nil?

    @memory = @current_result
    @history << "mw #{format_number(@memory)}"
    puts "Memory = #{format_number(@memory)}"
  end

  def memory_read
    @current_result = @memory
    @history << "mr = #{format_number(@memory)}"
    puts format_number(@current_result)
  end

  def show_history
    if @history.empty?
      puts "History is empty"
    else
      @history.each_with_index do |item, index|
        puts "#{index + 1}. #{item}"
      end
    end
  end

  def binary_operator?(input)
    ["+", "-", "*", "/", "mod", "pow"].include?(input)
  end

  def unary_operator?(input)
    ["--", "sqrt", "sin", "cos", "tan", "ctan", "exp", "ln", "!"].include?(input)
  end

  def apply_binary(op, a, b)
    case op
    when "+"
      a + b
    when "-"
      a - b
    when "*"
      a * b
    when "/"
      raise "Division by zero" if b == 0
      a.to_f / b
    when "mod"
      raise "Division by zero" if b == 0
      raise "mod only for integers" unless integer?(a) && integer?(b)
      a.to_i % b.to_i
    when "pow"
      a**b
    else
      raise "Unknown binary operator"
    end
  end

  def apply_unary(op, a)
    case op
    when "--"
      -a
    when "sqrt"
      raise "Negative sqrt" if a < 0
      Math.sqrt(a)
    when "sin"
      Math.sin(a)
    when "cos"
      Math.cos(a)
    when "tan"
      Math.tan(a)
    when "ctan"
      t = Math.tan(a)
      raise "ctan undefined" if t == 0
      1.0 / t
    when "exp"
      Math.exp(a)
    when "ln"
      raise "ln undefined" if a <= 0
      Math.log(a)
    when "!"
      factorial(a)
    else
      raise "Unknown unary operator"
    end
  end

  def expression_input?(input)
    input.include?("(") || input.include?(")") || input.include?(" ")
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
      type, value = token

      case type
      when :number
        output << token
      when :function
        stack << token
      when :operator
        while !stack.empty? &&
              ((stack.last[0] == :function) ||
              (stack.last[0] == :operator &&
               (precedence(stack.last) > precedence(token) ||
               (precedence(stack.last) == precedence(token) && !right_associative?(token)))))
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
          stack << factorial(a)
        else
          b = stack.pop
          a = stack.pop
          raise "Missing operands" if a.nil? || b.nil?
          stack << apply_binary(value, a, b)
        end
      when :function
        a = stack.pop
        raise "Missing operand" if a.nil?
        stack << apply_expression_function(value, a)
      end
    end

    raise "Invalid expression" unless stack.size == 1
    stack[0]
  end

  def apply_expression_function(func, a)
    case func
    when "neg"
      -a
    when "sqrt"
      raise "Negative sqrt" if a < 0
      Math.sqrt(a)
    when "sin"
      Math.sin(a)
    when "cos"
      Math.cos(a)
    when "tan"
      Math.tan(a)
    when "ctan"
      t = Math.tan(a)
      raise "ctan undefined" if t == 0
      1.0 / t
    when "exp"
      Math.exp(a)
    when "ln"
      raise "ln undefined" if a <= 0
      Math.log(a)
    else
      raise "Unknown function"
    end
  end

  def factorial(x)
    raise "Invalid factorial" if x < 0 || !integer?(x)
    (1..x.to_i).reduce(1, :*)
  end

  def integer?(x)
    x % 1 == 0
  end

  def number?(input)
    !!(input =~ /^-?\d+(\.\d+)?$/)
  end

  def format_number(num)
    if num.is_a?(Numeric) && num.finite? && num % 1 == 0
      num.to_i.to_s
    else
      num.to_s
    end
  end

  def push_stack
    raise "Nothing to push" if @current_result.nil?

    @stack << @current_result
    @history << "push #{format_number(@current_result)}"
    puts format_number(@current_result)
  end

  def pop_stack
    raise "Stack is empty" if @stack.empty?

    value = @stack.pop
    @current_result = value
    @history << "pop = #{format_number(value)}"
    puts format_number(value)
  end

  def start_primes
    raise "No left operand for primes" if @current_result.nil?
    raise "Operator already pending" if @pending_binary_op

    @pending_primes = true
    @primes_start = @current_result
    puts "primes"
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
    @history << "primes #{start_num}..#{end_num} => #{primes.map { |x| format_number(x) }.join(', ')}"
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
end

Calculator.new.start