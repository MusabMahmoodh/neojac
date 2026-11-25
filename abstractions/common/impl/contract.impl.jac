impl DataError.__str__ -> str {
    return f"{self.path} {self.problem}" if self.path != "" else self.problem;
}
