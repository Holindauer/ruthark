help:
	cat Makefile

all:
	@$(MAKE) futhark --no-print-directory
	@$(MAKE) generator --no-print-directory
	@$(MAKE) generated --no-print-directory
	@$(MAKE) user --no-print-directory
	@$(MAKE) twenty-first --no-print-directory

SRC_DIR := futhark_source
futhark:
	$(MAKE) -C $(SRC_DIR)

generator:
	cargo build -p lib_maker
	cargo run --bin lib_maker

generated:
	RUSTFLAGS=-Awarnings cargo build -p generated_lib
	@# Very quietly fix the generated code so we dont have to
	@# restore when we accidentally save and auto-format it,
	@# or have to suffer the eyestrain of poor formatting.
	@cargo fix -p generated_lib --allow-dirty --allow-staged 2> /dev/null

user:
	cargo build -p user_app
	cargo run --bin user_app

twenty-first:
	cargo build -p twenty-first
	cargo run --bin twenty-first

clean:
	cargo clean

RELEASE := 0.22.2
NAME := futhark-$(RELEASE)-linux-x86_64
TAR := $(NAME).tar.xz
get-futhark:
	curl https://futhark-lang.org/releases/$(TAR) --output $(TAR)
	tar -xf $(TAR)
	cd $(NAME) && sudo $(MAKE) install
	rm $(TAR) $(NAME) -rf
	@echo "===================================================="
	@echo "============= You now have Futhark! :D ============="
	@echo "===================================================="
	futhark -V
