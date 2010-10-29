# redMine - project management software
# Copyright (C) 2006-2007  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

require 'redmine/scm/adapters/bazaar_adapter'

class Repository::Bazaar < Repository
  attr_protected :root_url
  validates_presence_of :url

  def scm_adapter
    Redmine::Scm::Adapters::BazaarAdapter
  end
  
  def self.scm_name
    'Bazaar'
  end

  # Returns the identifier for the given bazaar changeset
  def self.changeset_identifier(changeset)
    changeset.scmid
  end

  # Returns the readable identifier for the given bazaar changeset
  def self.format_changeset_identifier(changeset)
    changeset.revision
  end

  def entries(path=nil, identifier=nil)
    entries = scm.entries(path, identifier)
    if entries
      entries.each do |e|
        next if e.lastrev.revision.blank?
        # Set the filesize unless browsing a specific revision
        if identifier.nil? && e.is_file?
          full_path = File.join(root_url, e.path)
          e.size = File.stat(full_path).size if File.file?(full_path)
        end
        c = Change.find(:first,
                        :include => :changeset,
                        :conditions => ["#{Change.table_name}.revision = ? and #{Changeset.table_name}.repository_id = ?", e.lastrev.revision, id],
                        :order => "#{Changeset.table_name}.revision DESC")
        if c
          e.lastrev.identifier = c.changeset.revision
          e.lastrev.name = c.changeset.revision
          e.lastrev.author = c.changeset.committer
        end
      end
    end
  end

  # With SCM's that have a sequential commit numbering, redmine is able to be
  # clever and only fetch changesets going forward from the most recent one
  # it knows about.  However, with bazaar, you never know if people have merged
  # commits into the middle of the repository history, so we should parse
  # the entire log. Since it's way too slow for large repositories, we only
  # parse 1 week before the last known commit.
  # The repository can still be fully reloaded by calling #clear_changesets
  # before fetching changesets (eg. for offline resync), you can set this up
  # as an external job with rake redmine:clear_and_fetch_changesets
  def fetch_changesets
    c = changesets.find(:first, :order => 'committed_on DESC')
    since = (c ? c.committed_on - 7.days : nil)

    revisions = scm.revisions('', nil, nil, :all => true, :since => since)
    return if revisions.nil? || revisions.empty?

    recent_changesets = changesets.find(:all, :conditions => ['committed_on >= ?', since])

    # Clean out revisions that are no longer in bazaar
    recent_changesets.each {|c| c.destroy unless revisions.detect {|r| r.scmid.to_s == c.scmid.to_s }}

    # Subtract revisions that redmine already knows about
    recent_revisions = recent_changesets.map{|c| c.scmid}
    revisions.reject!{|r| recent_revisions.include?(r.scmid)}

    # Save the remaining ones to the database
    revisions.each{|r| r.save(self)} unless revisions.nil?
  end

  # Finds and returns a revision with a number or the beginning of a hash
  def find_changeset_by_name(name)
    if /[^\d\.]/ =~ name
      e = changesets.find(:first, :conditions => ['scmid = ?', name.to_s])
    else
      e = changesets.find(:first, :conditions => ['revision = ?', name.to_s])
    end
    return e if e
    changesets.find(:first, :conditions => ['scmid LIKE ?', "#{name}%"])  # last ditch
  end

  def latest_changesets(path,rev,limit=10)
    revisions = scm.revisions(path, nil, rev, :limit => limit, :all => false)
    return [] if revisions.nil? || revisions.empty?

    changesets.find(
      :all,
      :conditions => [
        "scmid IN (?)",
        revisions.map!{|c| c.scmid}
      ],
      :order => 'committed_on DESC'
    )
  end

end
