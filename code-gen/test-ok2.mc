//OPIS: koriscenje dva heap-a
//RETURN: 4
int main() {
    int a;
    heap h = create_heap();
    heap c = create_heap();
    int b;
    
    c.push(5);
    c.push(1);

    h.push(4);

    a = h.root();
    
    return h.root() - c.isEmpty();
}