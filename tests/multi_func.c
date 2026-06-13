int add_one(int x) {
    return x + 1;
}

int times_two(int x) {
    return x * 2;
}

int main() {
    int a = add_one(5);
    int b = times_two(a);
    return b;
}