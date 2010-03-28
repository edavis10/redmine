# redminehelper: draft extension for Mercurial
# it's a draft to show a possible way to explore repository by the Redmine overhaul patch
# see: http://www.redmine.org/issues/4455
#
# Copyright 2010 Alessio Franceschelli (alefranz.net)
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

'''command to list revision of each file
'''

from mercurial import cmdutil, commands
from mercurial.i18n import _

def overhaul(ui, repo, rev=None, **opts):
    mf = repo[rev].manifest()
    for f in repo[rev]:
        try:
            fctx = repo.filectx(f, fileid=mf[f])
            ctx = fctx.changectx()
            ui.write('%s\t%d\t%s\n' %
                     (ctx,fctx.size(),f))
        except LookupError:
            pass

cmdtable = {
    'overhaul': (overhaul,commands.templateopts, _('hg overhaul [rev]'))
}
