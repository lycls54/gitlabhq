require 'spec_helper'

feature 'Diff note avatars', feature: true, js: true do
  include NoteInteractionHelpers

  let(:user)          { create(:user) }
  let(:project)       { create(:project, :public) }
  let(:merge_request) { create(:merge_request_with_diffs, source_project: project, author: user, title: "Bug NS-04") }
  let(:path)          { "files/ruby/popen.rb" }
  let(:position) do
    Gitlab::Diff::Position.new(
      old_path: path,
      new_path: path,
      old_line: nil,
      new_line: 9,
      diff_refs: merge_request.diff_refs
    )
  end
  let!(:note) { create(:diff_note_on_merge_request, project: project, noteable: merge_request, position: position) }

  before do
    project.team << [user, :master]
    login_as user
  end

  context 'discussion tab' do
    before do
      visit namespace_project_merge_request_path(project.namespace, project, merge_request)
    end

    it 'does not show avatars on discussion tab' do
      expect(page).not_to have_selector('.js-avatar-container')
      expect(page).not_to have_selector('.diff-comment-avatar-holders')
    end

    it 'does not render avatars after commening on discussion tab' do
      click_button 'Reply...'

      page.within('.js-discussion-note-form') do
        find('.note-textarea').native.send_keys('Test comment')

        click_button 'Comment'
      end

      expect(page).to have_content('Test comment')
      expect(page).not_to have_selector('.js-avatar-container')
      expect(page).not_to have_selector('.diff-comment-avatar-holders')
    end
  end

  context 'commit view' do
    before do
      visit namespace_project_commit_path(project.namespace, project, merge_request.commits.first.id)
    end

    it 'does not render avatar after commenting' do
      first('.diff-line-num').trigger('mouseover')
      find('.js-add-diff-note-button').click

      page.within('.js-discussion-note-form') do
        find('.note-textarea').native.send_keys('test comment')

        click_button 'Comment'

        wait_for_requests
      end

      visit namespace_project_merge_request_path(project.namespace, project, merge_request)

      expect(page).to have_content('test comment')
      expect(page).not_to have_selector('.js-avatar-container')
      expect(page).not_to have_selector('.diff-comment-avatar-holders')
    end
  end

  %w(inline parallel).each do |view|
    context "#{view} view" do
      before do
        visit diffs_namespace_project_merge_request_path(project.namespace, project, merge_request, view: view)

        wait_for_requests
      end

      it 'shows note avatar' do
        page.within find("[id='#{position.line_code(project.repository)}']") do
          find('.diff-notes-collapse').click

          expect(page).to have_selector('img.js-diff-comment-avatar', count: 1)
        end
      end

      it 'shows comment on note avatar' do
        page.within find("[id='#{position.line_code(project.repository)}']") do
          find('.diff-notes-collapse').click

          expect(first('img.js-diff-comment-avatar')["data-original-title"]).to eq("#{note.author.name}: #{note.note.truncate(17)}")
        end
      end

      it 'toggles comments when clicking avatar' do
        page.within find("[id='#{position.line_code(project.repository)}']") do
          find('.diff-notes-collapse').click
        end

        expect(page).to have_selector('.notes_holder', visible: false)

        page.within find("[id='#{position.line_code(project.repository)}']") do
          first('img.js-diff-comment-avatar').click
        end

        expect(page).to have_selector('.notes_holder')
      end

      it 'removes avatar when note is deleted' do
        open_more_actions_dropdown(note)

        page.within find(".note-row-#{note.id}") do
          find('.js-note-delete').click
        end

        wait_for_requests

        page.within find("[id='#{position.line_code(project.repository)}']") do
          expect(page).not_to have_selector('img.js-diff-comment-avatar')
        end
      end

      it 'adds avatar when commenting' do
        click_button 'Reply...'

        page.within '.js-discussion-note-form' do
          find('.js-note-text').native.send_keys('Test')

          click_button 'Comment'

          wait_for_requests
        end

        page.within find("[id='#{position.line_code(project.repository)}']") do
          find('.diff-notes-collapse').click

          expect(page).to have_selector('img.js-diff-comment-avatar', count: 2)
        end
      end

      it 'adds multiple comments' do
        3.times do
          click_button 'Reply...'

          page.within '.js-discussion-note-form' do
            find('.js-note-text').native.send_keys('Test')

            find('.js-comment-button').trigger 'click'

            wait_for_requests
          end
        end

        page.within find("[id='#{position.line_code(project.repository)}']") do
          find('.diff-notes-collapse').click

          expect(page).to have_selector('img.js-diff-comment-avatar', count: 3)
          expect(find('.diff-comments-more-count')).to have_content '+1'
        end
      end

      context 'multiple comments' do
        before do
          create_list(:diff_note_on_merge_request, 3, project: project, noteable: merge_request, in_reply_to: note)

          visit diffs_namespace_project_merge_request_path(project.namespace, project, merge_request, view: view)

          wait_for_requests
        end

        it 'shows extra comment count' do
          page.within find("[id='#{position.line_code(project.repository)}']") do
            find('.diff-notes-collapse').click

            expect(find('.diff-comments-more-count')).to have_content '+1'
          end
        end
      end
    end
  end
end
