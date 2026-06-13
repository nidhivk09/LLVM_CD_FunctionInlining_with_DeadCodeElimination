int fib(int n) {
    if (n < 2) return n;
    return fib(n - 1) + fib(n - 2);
}

int negate(int x) {
    return -x;
}

int main() {
    int f = fib(6);
    int r = negate(f);
    return r;
}