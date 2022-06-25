//OPIS: heap create
//RETURN: 8
int main() {
    heap h = create_heap();
    int a; 

    h.push(5);
    h.push(6);
    h.push(10);
    h.push(11);
    h.push(12);
    h.push(13);
    h.push(3);
    a = h.pop();
    
    return a + h.root();
}