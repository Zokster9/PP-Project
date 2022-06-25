//OPIS: heap create
//RETURN: 3
int main() {
    heap h = create_heap(); 

    h.push(5);
    h.push(6);
    h.push(10);
    h.push(11);
    h.push(12);
    h.push(13);
    h.push(3);
    
    return h.root();
}