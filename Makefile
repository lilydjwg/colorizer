.PHONY: all clean install uninstall
INSTALLED=$(HOME)/.vim/plugin/colorizer.vim

all:
	@echo "Available phony targets: install, uninstall"

install: $(INSTALLED)

$(INSTALLED): plugin/colorizer.vim
	cp $< $@

uninstall:
	rm $(INSTALLED)
