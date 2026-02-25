def add(a, b):
    return a + b


def subtract(a, b):
    return a - b


def multiply(a, b):
    return a * b


def divide(a, b):
    if b == 0:
        raise ValueError("Cannot divide by zero")
    return a / b


OPERATIONS = {
    '+': add,
    '-': subtract,
    '*': multiply,
    '/': divide,
}


def calculate(expression):
    """Parse and evaluate a simple 'number operator number' expression."""
    parts = expression.split()
    if len(parts) != 3:
        raise ValueError("Enter an expression like: 3 + 5")

    a_str, op, b_str = parts

    if op not in OPERATIONS:
        raise ValueError(f"Unknown operator '{op}'. Use one of: {', '.join(OPERATIONS)}")

    try:
        a = float(a_str)
        b = float(b_str)
    except ValueError:
        raise ValueError(f"Invalid numbers: '{a_str}', '{b_str}'")

    result = OPERATIONS[op](a, b)
    return int(result) if result == int(result) else result


def main():
    print("Simple Calculator")
    print("Enter expressions like: 3 + 5, 10 / 2, 7 * 8")
    print("Type 'quit' to exit.\n")

    while True:
        try:
            user_input = input("> ").strip()
        except (EOFError, KeyboardInterrupt):
            print("\nGoodbye!")
            break

        if user_input.lower() in ("quit", "exit", "q"):
            print("Goodbye!")
            break

        if not user_input:
            continue

        try:
            result = calculate(user_input)
            print(f"= {result}")
        except ValueError as e:
            print(f"Error: {e}")


if __name__ == "__main__":
    main()
