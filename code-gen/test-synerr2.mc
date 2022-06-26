//OPIS: vrsi se poziv heap funkcije bez zagrada
//RETURN: 4
int main() {
    heap h = create_heap();
    int a;
    int b;
    a = 3 + 4;
    h.push(4);
    h.push(5);
    b = h.root;
    
    return b;
}