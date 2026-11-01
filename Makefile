# İnce kabuk: tüm iş ./ro içinde.
RO := ./ro

.PHONY: all generate check test validate rpm install-user clean

all: generate

generate:
	$(RO) generate

check:
	$(RO) generate --check
	$(RO) validate

test:
	python3 -m unittest discover -s tests -t .

validate:
	$(RO) validate

rpm:
	$(RO) rpm-build

install-user:
	$(RO) install --local

clean:
	rm -rf build
