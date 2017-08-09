ifeq ($(LLVM_DEBUG),1)
LLVM_BUILDTYPE := Debug
else
LLVM_BUILDTYPE := Release
endif
LLVM_CMAKE_BUILDTYPE := $(LLVM_BUILDTYPE)
ifeq ($(LLVM_ASSERTIONS),1)
LLVM_BUILDTYPE := $(LLVM_BUILDTYPE)+Asserts
endif
LLVM_FLAVOR := $(LLVM_BUILDTYPE)
ifeq ($(LLVM_SANITIZE),1)
ifeq ($(SANITIZE_MEMORY),1)
LLVM_BUILDTYPE := $(LLVM_BUILDTYPE)+MSAN
else
LLVM_BUILDTYPE := $(LLVM_BUILDTYPE)+ASAN
endif
endif

LLVM_SRC_DIR:=$(SRCCACHE)/llvm-$(LLVM_VER)
LLVM_BUILD_DIR:=$(BUILDDIR)/llvm-$(LLVM_VER)
LLVM_BUILDDIR_withtype := $(LLVM_BUILD_DIR)/build_$(LLVM_BUILDTYPE)
