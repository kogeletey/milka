# Crystal Coding Rules - KISS (Keep It Simple, Stupid) Principles
# Clear Functions and Proper Typings

## Basic Examples

```crystal
# Example of a simple, clear function with proper typing
def add_numbers(a : Int32, b : Int32) : Int32
  a + b
end

# Example with optional types
def format_message(text : String, prefix : String? = nil) : String
  if prefix
    "#{prefix}: #{text}"
  else
    text
  end
end

# Example with array typing
def process_items(items : Array(String)) : Array(String)
  items.map { |item| item.upcase }
end

# Example with hash typing
def create_config(settings : Hash(String, String)) : Hash(String, String)
  settings.merge({"created_at" => Time.local.to_s})
end
```

## Class Example

```crystal
# Example class with clear property typing
class SimpleData
  property id : Int32
  property name : String
  property active : Bool

  def initialize(@id : Int32, @name : String, @active : Bool = true)
  end

  def to_s : String
    "SimpleData(id: #{@id}, name: #{@name}, active: #{@active})"
  end
end
```

## KISS Principle Examples

```crystal
# Following KISS principle - Simple, Clear, and Properly Typed
module KissPrinciples
  # Functions should have clear names
  def self.calculate_total(items : Array(Float64)) : Float64
    items.sum
  end

  # Use appropriate types for clarity
  def self.validate_email(email : String) : Bool
    email.includes?("@") && email.includes?(".")
  end

  # Keep methods focused on single responsibilities
  def self.format_currency(amount : Float64) : String
    "$#{amount.round(2)}"
  end
end
```