int fib(int n) { ... } // Left intact (recursive)

int main() {
    int f = fib(6);
    // negate(f) was inlined
    int r = -f;
    return r;
}