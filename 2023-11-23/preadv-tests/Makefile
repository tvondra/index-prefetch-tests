all: fadvise-test preadv2-test preadv2-fadvise-test

fadvise-test:
	gcc -O2 -o fadvise-test fadvise-test.c

preadv2-test:
	gcc -O2 -o preadv2-test preadv2-test.c

preadv2-fadvise-test:
	gcc -O2 -o preadv2-fadvise-test preadv2-fadvise-test.c

clean:
	rm -f fadvise-test preadv2-test preadv2-fadvise-test