# Test factorial functions
@assert log(factorial(5)) == lfactorial(5)
@assert factorial(6) == 720
@assert factorial(10,2) == factorial(10)/factorial(2)