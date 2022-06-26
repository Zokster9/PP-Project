//OPIS: vrsi se dodela elementa iz heapa na unsigned varijablu
//RETURN: 4
int main() {
    heap h = create_heap();
    unsigned a;
    int b;
    h.push(3);
    h.push(5);
    a = h.root();
    b = 4;
    
    return b;
}