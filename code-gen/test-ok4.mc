//OPIS: heap size dodela
//RETURN: 5
int main() {
    heap h = create_heap();
    
    h.push(4);
    h.push(5);
    h.pop();
    
    return h.root();
}