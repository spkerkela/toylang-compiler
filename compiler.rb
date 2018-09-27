#!/usr/bin/env ruby

code = """def main(x,y) 
  add(add(x,y),4020)
end
"""

# Tokens supported
TOKENS = [
  [:def, /\bdef\b/],
  [:end, /\bend\b/],
  [:identifier, /\b[a-zA-Z]+\b/],
  [:integer, /\b\d+\b/],
  [:oparen, /\(/],
  [:cparen, /\)/],
  [:comma, /,/]
]

# A structure holding a tokentype and token value
Token = Struct.new(:type, :value)

"Tokenizes code (string)"
class Tokenizer 
  def initialize(code)
    @code = code
  end

  # Create token array from code
  def tokenize
    tokens = []
    until @code.empty?
      tokens << tokenize_one
      @code = @code.strip
    end
    return tokens
  end

  # Create the next token
  def tokenize_one
    TOKENS.each do | type, re|
      re = /\A(#{re})/
      if @code =~ re
        value = $1
        @code = @code[value.length..-1]
        return Token.new(type, value)
      end
    end
    raise RuntimeError.new("Couldn't match token on #{@code.inspect}")
  end
end

# Parses a list of tokens into an AST
class Parser
  def initialize(tokens)
    @tokens = tokens
  end

  def parse
    parse_def
  end

  # Parse function definiton
  def parse_def
    consume(:def)
    name = consume(:identifier).value
    arg_names = parse_arg_names
    body = parse_expr
    consume(:end)
    DefNode.new(name, arg_names, body)
  end

  # Parse expression
  def parse_expr
    if peek(:integer)
      parse_integer
    elsif peek(:identifier) && peek(:oparen, 1)
      parse_call
    else
      parse_var_ref
    end
  end

  # Parse function call
  def parse_call
    name = consume(:identifier).value
    arg_exprs = parse_arg_exprs
    CallNode.new(name, arg_exprs)
  end

  # Parse function argument expressions
  def parse_arg_exprs
    arg_exprs = []
    consume(:oparen)
    if !peek(:cparen)
      arg_exprs << parse_expr
      while peek(:comma)
        consume(:comma)
        arg_exprs << parse_expr
      end
    end
    consume(:cparen)
    arg_exprs
  end

  # Parse variable reference
  def parse_var_ref
    VarRefNode.new(consume(:identifier).value)
  end

  # Parse integer literal
  def parse_integer
    IntegerNode.new(consume(:integer).value.to_i)
  end

  # Parse function argument names
  def parse_arg_names
    arg_names = []
    consume(:oparen)
    if peek(:identifier)
      arg_names << consume(:identifier).value
      while peek(:comma)
        consume(:comma)
        arg_names << consume(:identifier).value
      end
    end
    consume(:cparen)
    arg_names
  end

  # Peek at the next token, or a token specified by an offset
  def peek(expected_type, offset=0)
    @tokens.fetch(offset).type == expected_type
  end

  # Consume a token, throw an error if next token not what expected
  def consume(expected_type)
    token = @tokens.shift
    if token.type == expected_type
      token
    else
      raise RuntimeError.new(
        "Expected token type #{expected_type.inspect} but got #{token.type.inspect}"
      )
    end
  end
end

# Node representing function definiton
DefNode = Struct.new(:name, :arg_names, :body)
# Node representing integer
IntegerNode = Struct.new(:value)
# Node representing function call
CallNode  = Struct.new(:name, :arg_exprs)
# Node representing variable reference
VarRefNode = Struct.new(:value)

# Generates code from AST
class Generator
  # Generates javascript from an AST
  def generate(node)
    case node
    when DefNode
      "function %s(%s) { return %s};" % [node.name,
        node.arg_names.join(","),
        generate(node.body)
      ]
    when CallNode
      "%s(%s)" % [node.name, node.arg_exprs.map { |expr| generate(expr)}.join(",")]
    when VarRefNode 
      node.value
    when IntegerNode 
      node.value
    else
      raise RuntimeError.new("Unexepected node type: #{node.class}")
    end
  end
end

tokenizer = Tokenizer.new(code)

tokens = tokenizer.tokenize

tree = Parser.new(tokens).parse
generated = Generator.new.generate(tree)
# Functions injected into resulting javascript file
RUNTIME = [
  "function print(x) {console.log(x);}",
  "function add(x, y) {return x + y;}",
]

puts RUNTIME.concat([generated,"print(main(10,20));"]).join("\n")