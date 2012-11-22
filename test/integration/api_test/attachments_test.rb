# Redmine - project management software
# Copyright (C) 2006-2012  Jean-Philippe Lang
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

require File.expand_path('../../../test_helper', __FILE__)

class ApiTest::AttachmentsTest < ActionController::IntegrationTest
  fixtures :projects, :trackers, :issue_statuses, :issues,
           :enumerations, :users, :issue_categories,
           :projects_trackers,
           :roles,
           :member_roles,
           :members,
           :enabled_modules,
           :workflows,
           :attachments

  def setup
    Setting.rest_api_enabled = '1'
    set_fixtures_attachments_directory
  end

  def teardown
    set_tmp_attachments_directory
  end

  context "/attachments/:id" do
    context "GET" do
      should "return the attachment" do
        get '/attachments/7.xml', {}, credentials('jsmith')
        assert_response :success
        assert_equal 'application/xml', @response.content_type
        assert_tag :tag => 'attachment',
          :child => {
            :tag => 'id',
            :content => '7',
            :sibling => {
              :tag => 'filename',
              :content => 'archive.zip',
              :sibling => {
                :tag => 'content_url',
                :content => 'http://www.example.com/attachments/download/7/archive.zip'
              }
            }
          }
      end

      should "deny access without credentials" do
        get '/attachments/7.xml'
        assert_response 401
        set_tmp_attachments_directory
      end
    end
  end

  context "/attachments/download/:id/:filename" do
    context "GET" do
      should "return the attachment content" do
        get '/attachments/download/7/archive.zip', {}, credentials('jsmith')
        assert_response :success
        assert_equal 'application/octet-stream', @response.content_type
        set_tmp_attachments_directory
      end

      should "deny access without credentials" do
        get '/attachments/download/7/archive.zip'
        assert_response 302
        set_tmp_attachments_directory
      end
    end
  end

  context "POST /uploads" do
    should "return the token" do
      set_tmp_attachments_directory
      assert_difference 'Attachment.count' do
        post '/uploads.xml', 'File content', {"CONTENT_TYPE" => 'application/octet-stream'}.merge(credentials('jsmith'))
        assert_response :created
        assert_equal 'application/xml', response.content_type

        xml = Hash.from_xml(response.body)
        assert_kind_of Hash, xml['upload']
        token = xml['upload']['token']
        assert_not_nil token

        attachment = Attachment.first(:order => 'id DESC')
        assert_equal token, attachment.token
        assert_nil attachment.container
        assert_equal 2, attachment.author_id
        assert_equal 'File content'.size, attachment.filesize
        assert attachment.content_type.blank?
        assert attachment.filename.present?
        assert_match /\d+_[0-9a-z]+/, attachment.diskfile
        assert File.exist?(attachment.diskfile)
        assert_equal 'File content', File.read(attachment.diskfile)
      end
    end

    should "not accept other content types" do
      set_tmp_attachments_directory
      assert_no_difference 'Attachment.count' do
        post '/uploads.xml', 'PNG DATA', {"CONTENT_TYPE" => 'image/png'}.merge(credentials('jsmith'))
        assert_response 406
      end
    end

    should "return errors if file is too big" do
      set_tmp_attachments_directory
      with_settings :attachment_max_size => 1 do
        assert_no_difference 'Attachment.count' do
          post '/uploads.xml', ('x' * 2048), {"CONTENT_TYPE" => 'application/octet-stream'}.merge(credentials('jsmith'))
          assert_response 422
          assert_tag 'error', :content => /exceeds the maximum allowed file size/
        end
      end
    end
  end
end
