int big(int x) { ... } // Left intact (skipped)
int recur(int n) { ... } // Left intact (recursive)

int main() {
    // tiny(10) was inlined
    int a = 10 + 1;
    int b = big(a);
    int c = recur(5);
    int total = b + c;
    return total;
}