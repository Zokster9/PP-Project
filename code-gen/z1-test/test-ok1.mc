//OPIS: switch sa break i default
//RETURN: 10
int main() {
    int state;
    int x;
    state = 5;
    switch(state) {
	case 1: x = 1; break;
	case 2: { x = 5;} break;
	default: x = 10;
    }
    
    return x;
}
