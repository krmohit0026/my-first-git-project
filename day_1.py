# To create a virtual environment, run this in your shell (not in Python):
#     python -m venv .openv
# This file should contain Python code. The line above is a shell command which caused a SyntaxError
# when you tried to run the file with Python. Replace or remove it if you didn't mean to run it as code.

import csv

file = open("students.csv","r")
reader = csv.DictReader(file)

print("reading student data.....\n")

for row in reader:
    print(f"Name: {row['name']}, Age: {row['age']}, Grade: {row['grade']}")

file.close()