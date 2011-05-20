CPANM        := cpanm -q -n
#CPAN_MIRROR := http://cpan.sgn.cornell.edu/CPAN/
CPAN_MIRROR  := /data/shared/cpan-mirror/cpan
LL_NAME      := $(PWD)/extlibs
DPAN         := $(PWD)/dpan
DISTS_LIST   := $(DPAN)/dists.list

MISSING_DEPS   := List::MoreUtils
DPAN_BLACKLIST := JSON::PP common::sense

all: $(LL_NAME)

$(LL_NAME): inc/  Makefile.PL
	mkdir -p $(DPAN);
	# install the blacklisted modules from the upstream mirror without trying to use the dpan
	$(CPANM)                      -L $(LL_NAME) --mirror $(CPAN_MIRROR) --mirror-only $(DPAN_BLACKLIST);
	# try first to installdeps from our DPAN as much as possible
	-$(CPANM)                        -L $(LL_NAME) --mirror $(DPAN)        --mirror-only --installdeps .;
	# then try to installdeps from the upstream mirror, saving stuff in the dpan
	$(CPANM) --save-dists $(DPAN) -L $(LL_NAME) --mirror $(CPAN_MIRROR) --mirror-only --installdeps .;
	# and update the dpan indexes for our next run
	cd $(DPAN) && dpan

inc/: Makefile.PL
	perl Makefile.PL < /dev/null

clean:
	rm -rf .tmp_ll $(LL_NAME) .dists.list.tmp;

.PHONY: $(LL_NAME)
