//OPIS: expression sa varijablom i heap funkcijom
//RETURN: 10
int main() {
    heap h = create_heap();
    int a;
    heap c = create_heap();
    
    h.push(4);
    h.push(5);
    a = h.pop();
    
    return h.root() + a + c.isEmpty();
}