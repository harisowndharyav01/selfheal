# Define directories
OUTPUTDIR = ../output
OBJDIR = $(OUTPUTDIR)/object

# Define target
TARGET_SO = $(OBJDIR)/selfheal.so

# Source and include directories
SRCDIR = .
INCDIR_PUB =
INCDIR_PRIV = ../include_priv
INCDIRS = $(INCDIR_PUB) $(INCDIR_PRIV) \
          $(if $(STAGINGDIR), $(STAGINGDIR)/include) \
          $(if $(STAGINGDIR), $(STAGINGDIR)/usr/include)
STAGING_LIBDIR = $(if $(STAGINGDIR), -L$(STAGINGDIR)/lib) \
                 $(if $(STAGINGDIR), -L$(STAGINGDIR)/usr/lib)

# Source and object files
SOURCES = $(wildcard $(SRCDIR)/*.c)
OBJECTS = $(addprefix $(OBJDIR)/,$(notdir $(SOURCES:.c=.o)))

# Compilation and linking flags
CFLAGS += -Werror -Wall -Wextra -Wformat=2 -Wshadow \
          -Wwrite-strings -Wredundant-decls -Wmissing-declarations \
          -Wno-attributes -Wno-format-nonliteral -fPIC -g3 \
          $(addprefix -I ,$(INCDIRS)) -DSAHTRACES_ENABLED

CFLAGS += -Wno-unused-parameter

LDFLAGS += $(STAGING_LIBDIR) -shared -fPIC \
           -lamxc -lamxp -lamxd -lamxo -lsahtrace

# Targets
all: $(TARGET_SO)

$(TARGET_SO): $(OBJECTS)
	$(CC) -Wl,-soname,selfheal.so -o $@ $(OBJECTS) $(LDFLAGS)

$(OBJDIR)/%.o: $(SRCDIR)/%.c | $(OBJDIR)/
	$(CC) $(CFLAGS) -c -o $@ $<
	@$(CC) $(CFLAGS) -MM -MP -MT '$(@) $(@:.o=.d)' -MF $(@:.o=.d) $(<)

$(OBJDIR)/:
	mkdir -p $@

clean:
	rm -rf $(OUTPUTDIR)/ selfheal-*.* selfheal_*.*

install: all
	$(INSTALL) -D -p -m 0644 $(TARGET_SO) $(DESTDIR)/usr/lib/amx/selfheal/selfheal.so
	$(INSTALL) -d -m 0755 $(DESTDIR)/usr/bin
	ln -sfr $(DESTDIR)/usr/bin/amxrt $(DESTDIR)/usr/bin/selfheal

.PHONY: all clean install
