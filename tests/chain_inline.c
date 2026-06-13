int funcC(int x) {
    return x + 10;
}

int funcB(int x) {
    return funcC(x);
}

int funcA(int x) {
    return funcB(x);
}

int main() {
    int val = funcA(5);
    return val;
}