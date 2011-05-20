CPAN_MIRROR := http://cpan.sgn.cornell.edu/CPAN/
LL_NAME     := extlibs
DPAN        := $(PWD)/dpan
DISTS_LIST  := $(DPAN)/dists.list

all: $(LL_NAME)

dists.list:
	cpanm -q --save-dists $(DPAN) -L .tmp_ll --mirror $(DPAN) --mirror $(CPAN_MIRROR) --mirror-only --scandeps --format dists  . | grep .tar.gz > .dists.list.tmp;
	mv .dists.list.tmp $(DISTS_LIST);
	rm -f .tmp_ll .dists.list.tmp;

$(LL_NAME): $(DISTS_LIST)
	cpanm -n -q --mirror $(DPAN) --mirror $(CPAN_MIRROR) -L $(LL_NAME) Module::Build Module::Install;
	cpanm -n -q --mirror $(DPAN) --mirror-only -L $(LL_NAME) `cat $(DISTS_LIST)`;
	cpanm -n -q --mirror $(CPAN_MIRROR) --mirror-only -L $(LL_NAME) --installdeps . ;

clean:
	rm -rf .tmp_ll $(LL_NAME) $(DISTS_LIST) .dists.list.tmp;
