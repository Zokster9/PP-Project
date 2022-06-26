//OPIS: expression sa varijablom i heap funkcijom
//RETURN: 9
int main() {
    heap h = create_heap();
    int a;
    
    h.push(4);
    h.push(5);
    a = h.pop();
    
    return h.root() + a;
}