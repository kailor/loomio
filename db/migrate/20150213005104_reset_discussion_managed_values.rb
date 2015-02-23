class ResetDiscussionManagedValues < ActiveRecord::Migration
  def create_progress_bar(total)
    ProgressBar.create(format: "(\e[32m%c/%C\e[0m) %a |%B| \e[31m%e\e[0m ",
                       progress_mark: "\e[32m/\e[0m",
                       total: total)
  end

  def change
    raise "migration does not work" if Event.where('discussion_id is not null').where('sequence_id is null').any?

    puts "Resetting items_count, comments_count for all discussions"
    bar = create_progress_bar(Discussion.count)
    Discussion.find_each do |discussion|
      bar.increment
      Discussion.where(id: discussion.id).update_all(items_count: discussion.items.count,
                                                     comments_count: discussion.comments.count)
    end

    puts "Resetting last_comment_at for all discussions"
    bar = create_progress_bar(Discussion.count)
    Comment.select('DISTINCT ON (discussion_id) id, *').order('discussion_id, comments.created_at desc').each do |comment|
      bar.increment
      Discussion.where(id: comment.discussion_id).update_all(last_comment_at: comment.created_at)
    end

    puts "Resetting last_item_at, last_sequence_id for all discussions"
    bar = create_progress_bar(Discussion.count)
    Event.select('DISTINCT ON (discussion_id) id, *').
          where('discussion_id is not null').
          order('discussion_id, events.created_at desc').each do |item|
      bar.increment
      raise item.inspect if item.sequence_id.nil?
      Discussion.where(id: item.discussion_id).update_all(last_item_at: item.created_at,
                                                          last_sequence_id: item.sequence_id || 0)
    end

    #first_sequence_id
    puts "Resetting first_sequence_id for all discussions"
    bar = create_progress_bar(Discussion.count)
    Event.select('DISTINCT ON (discussion_id) id, *').
          where('discussion_id is not null').
          order('discussion_id, events.created_at asc').each do |item|
      bar.increment
      Discussion.where(id: item.discussion_id).update_all(first_sequence_id: item.sequence_id)
    end
  end
end
