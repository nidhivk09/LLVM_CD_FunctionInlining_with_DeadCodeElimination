int main() {
    // square() was inlined 5 times
    int r0 = 1 * 1;
    int r1 = 2 * 2;
    int r2 = 3 * 3;
    int r3 = 4 * 4;
    int r4 = 5 * 5;
    int sum0 = r0 + r1;
    int sum1 = sum0 + r2;
    int sum2 = sum1 + r3;
    int sum3 = sum2 + r4;
    return sum3;
}