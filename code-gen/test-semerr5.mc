//OPIS: vrsi se pushovanje unsigned literala iz heapa na unsigned varijablu
//RETURN: 4
int main() {
    heap h = create_heap();
    unsigned a;
    int b;
    h.push(3);
    h.push(5u);
    b = 4;
    
    return b;
}