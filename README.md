# sopacker

sopacker是一个用于打包可执行文件和动态库的脚本工程. 生成的新可执行文件可以在大部分Linux上运行.

sopacker is a script for packaging an executable file and all its dependent dynamic link libraries. The resulting executable can theoretically run on any Linux environment.

## Usage

这个项目本身除了patchelf, binutils外没有依赖. 但是需要满足patchelf的依赖. https://github.com/NixOS/patchelf/tree/c40128936fc804b74abddaa0bc1d8ef6e5dba48e

This project has no dependencies other than patchelf and binutils. However, the dependencies of patchelf need to be satisfied. https://github.com/NixOS/patchelf/tree/c40128936fc804b74abddaa0bc1d8ef6e5dba48e

除此以外需要binutils. 例如debian/ubuntu: `apt install binutils`

In addition, binutils is required. For example, on Debian/Ubuntu, run `apt install binutils` to install it.

第一次执行会update submodule并编译出patchelf. 如果有一个已经编译的patchelf, 则不会触发编译以节省时间.

The first time you run it, it will update the submodule and compile patchelf. If there is already a compiled patchelf in the root directory, it will not trigger the compilation.

Run `./packer -h` to get the instructions:

```
Usage: ./packer [executable_file] [--output=output_dir]
  executable_file: the path to the executable file
  --output: (optional) the path to the output directory (default: ./output)
```

以bpftrace举例. 最新版本的bpftrace编译出的结果是不能在debian9上运行的.

For example, to package bpftrace:

```
./packer [bpftrace path]
```

一个新的bpftrace会出现在output这个文件夹中. 这个bpftrace就可以在debian9上运行.

A new bpftrace will be generated in the output folder in the current directory. This bpftrace is the packaged version and can be run on any environment.

## Principle

修改所有的动态库和可执行文件里的解释器和动态库路径到本地.

Modify the interpreter and dynamic library path to the local path in all dynamic libraries and executable files.

打包出的新可执行文件实际上是个bash脚本, 后面带着所有已经修改过的动态库和可执行文件的tar包. 运行时将tar包解压到/tmp下的一个特定文件夹. 已经解压过则不解压. 最后执行/tmp下的可执行文件.

The resulting executable file is actually a bash script with a tarball of all modified dynamic libraries and executable files appended to it. When running, the tarball is extracted to a specific folder under /tmp. If it has already been extracted before, it will not be extracted again. Finally, the executable file under /tmp is executed.