These scripts are primarily meant to support the use of
[Janky](https://github.com/github/janky). To use them, read the contents of this
repository into a `script` folder:

```
$ git remote add objc-build-scripts https://github.com/jspahrsummers/objc-build-scripts.git
$ git fetch objc-build-scripts
$ git read-tree --prefix=script/ -u objc-build-scripts/master
```

Then commit the changes to incorporate the scripts into your own repository's
history. You can also freely tweak the scripts for your specific project's
needs.

To bring in upstream changes later:

```
$ git fetch -p objc-build-scripts
$ git merge -Xsubtree=script objc-build-scripts/master
```
