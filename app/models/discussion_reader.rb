class DiscussionReader < ActiveRecord::Base
  include HasVolume

  belongs_to :user
  belongs_to :discussion

  validates_presence_of :discussion, :user
  validates_uniqueness_of :user_id, scope: :discussion_id

  scope :for_user, -> (user) { where(user_id: user.id) }

  def self.for(user: nil, discussion: nil)
    if user.is_logged_in?
      where(user_id: user.id, discussion_id: discussion.id).first_or_initialize do |dr|
        dr.discussion = discussion
        dr.user = user
      end
    else
      new(discussion: discussion)
    end
  end

  def volume
    super || membership.volume
  end

  def follow!
    change_volume! :email # deprecated, use change_volume! :email directly
  end

  def unfollow!
    change_volume! :normal # deprecated, use change_volume! :normal directly
  end

  def following?
    volume.email? # deprecated, use self.volume.email? directly
  end

  def first_read?
    last_read_at.blank?
  end

  def user_or_logged_out_user
    user || LoggedOutUser.new
  end

  def unread_comments_count
    #we count the discussion itself as a comment.. but it is comment 0
    if last_read_at.blank?
      discussion.comments_count.to_i + 1
    else
      discussion.comments_count.to_i - read_comments_count
    end
  end

  def unread_items_count
    discussion.items_count - read_items_count
  end

  def unread_activity_count
    if last_read_at.blank?
      discussion.salient_items_count + 1
    else
      discussion.salient_items_count - read_salient_items_count
    end
  end

  def has_read?(event)
    if last_read_at.present?
      self.last_read_at >= event.created_at
    else
      false
    end
  end

  def unread_activity?
    last_read_at.nil? || (discussion.last_activity_at > last_read_at)
  end

  def viewed!(age_of_last_read_item = nil)
    return if user.nil?
    self.last_read_at = age_of_last_read_item || discussion.last_activity_at
    reset_counts!
  end

  def reset_comment_counts
    self.read_comments_count = read_comments.count
  end

  def reset_comment_counts!
    reset_comment_counts
    save!(validate: false)
  end

  def reset_non_comment_counts
    self.read_items_count = read_items.count
    self.read_salient_items_count = read_salient_items.count
    self.last_read_sequence_id = if read_items_count == 0
                                   0
                                 else
                                   read_items.last.sequence_id
                                 end
  end

  def reset_non_comment_counts!
    reset_non_comment_counts
    save!(validate: false)
  end

  def reset_counts!
    reset_comment_counts
    reset_non_comment_counts
    save!(validate: false)
  end


  def first_unread_page
    per_page = Discussion::PER_PAGE
    remainder = read_items_count % per_page

    if read_items_count == 0
      1
    elsif remainder == 0 && discussion.items_count > read_items_count
      (read_items_count.to_f / per_page).ceil + 1
    else
      (read_items_count.to_f / per_page).ceil
    end
  end

  def read_comments(time = nil)
    discussion.comments.where('comments.created_at <= ?', time || last_read_at).chronologically
  end

  def read_items(time = nil)
    discussion.items.where('events.created_at <= ?', time || last_read_at).chronologically
  end

  def read_salient_items(time = nil)
    discussion.salient_items.where('events.created_at <= ?', time || last_read_at).chronologically
  end

  private
  def membership
    discussion.group.membership_for(user)
  end
end
