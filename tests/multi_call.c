int square(int x) {
    return x * x;
}

int main() {
    int r0 = square(1);
    int r1 = square(2);
    int r2 = square(3);
    int r3 = square(4);
    int r4 = square(5);
    int sum0 = r0 + r1;
    int sum1 = sum0 + r2;
    int sum2 = sum1 + r3;
    int sum3 = sum2 + r4;
    return sum3;
}