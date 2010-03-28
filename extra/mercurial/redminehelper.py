# redminehelper: Redmine helper extension for Mercurial
# it's a draft to show a possible way to explore repository by the Redmine overhaul patch
# see: http://www.redmine.org/issues/4455
#
# Copyright 2010 Alessio Franceschelli (alefranz.net)
# Copyright 2010 Yuya Nishihara <yuya@tcha.org>
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

'''command to list revision of each file
'''

import re, time
from mercurial import cmdutil, commands, node, error

SPECIAL_TAGS = ('tip',)

def rhsummary(ui, repo, **opts):
    """output the summary of the repository"""
    # see mercurial/commands.py:tip
    ui.write(':tip: rev node\n')
    tipctx = repo[len(repo) - 1]
    ui.write('%d %s\n' % (tipctx.rev(), tipctx))

    # see mercurial/commands.py:root
    ui.write(':root: path\n')
    ui.write(repo.root + '\n')

    # see mercurial/commands.py:tags
    ui.write(':tags: rev node name\n')
    for t, n in reversed(repo.tagslist()):
        if t in SPECIAL_TAGS:
            continue
        try:
            r = repo.changelog.rev(n)
        except error.LookupError:
            r = -1
        ui.write('%d %s %s\n' % (r, node.short(n), t))

    # see mercurial/commands.py:branches
    def iterbranches():
        for t, n in repo.branchtags().iteritems():
            yield t, n, repo.changelog.rev(n)

    ui.write(':branches: rev node name\n')
    for t, n, r in sorted(iterbranches(), key=lambda e: e[2], reverse=True):
        if repo.lookup(r) in repo.branchheads(t, closed=False):
            ui.write('%d %s %s\n' % (r, node.short(n), t))  # only open branch

def rhentries(ui, repo, path='', **opts):
    """output the entries of the specified directory"""
    rev = opts.get('rev')
    pathprefix = (path.rstrip('/') + '/').lstrip('/')

    # TODO: clean up
    dirs, files = {}, {}
    mf = repo[rev].manifest()
    for f in repo[rev]:
        if not f.startswith(pathprefix):
            continue

        name = re.sub(r'/.*', '', f[len(pathprefix):])
        if '/' in f[len(pathprefix):]:
            dirs[name] = (name,)
        else:
            try:
                fctx = repo.filectx(f, fileid=mf[f])
                ctx = fctx.changectx()
                tm, tzoffset = ctx.date()
                localtime = int(tm) + tzoffset - time.timezone
                files[name] = (ctx.rev(), node.short(ctx.node()), localtime,
                               fctx.size(), name)
            except LookupError:  # TODO: when this occurs?
                pass

    ui.write(':dirs: name\n')
    for n, v in sorted(dirs.iteritems(), key=lambda e: e[0]):
        ui.write(' '.join(v) + '\n')

    ui.write(':files: rev node time size name\n')
    for n, v in sorted(files.iteritems(), key=lambda e: e[0]):
        ui.write(' '.join(str(e) for e in v) + '\n')


cmdtable = {
    'rhsummary': (rhsummary, [], 'hg rhsummary'),
    'rhentries': (rhentries,
                  [('r', 'rev', '', 'show the specified revision')],
                  'hg rhentries [path]'),
}
