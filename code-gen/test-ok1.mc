//OPIS: heap create
//RETURN: 10
int main() {
    heap h = create_heap();
    int a;
    int b;

    h.push(5);
    h.push(6);
    h.push(10);
    h.push(11);
    h.push(12);
    h.push(13);
    h.push(3);
    h.pop();
    
    return h.size() - h.isEmpty() + h.pop();
}