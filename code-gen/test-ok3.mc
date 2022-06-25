//OPIS: heap isEmpty dodela
//RETURN: 16
int main() {
    heap h = create_heap();
    int a;
    int b;
    heap e = create_heap();
    int c;
    int f;
    heap d = create_heap();

    h.push(10);
    h.push(11);
    h.push(3);
    h.push(1);

    d.push(20);

    e.push(13);
    e.push(11);
    
    return h.pop() + h.root() + d.size() + e.pop();
}