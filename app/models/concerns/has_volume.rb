module HasVolume
  extend ActiveSupport::Concern

  included do
    enum volume: [:mute, :normal, :email]
  end

  def change_volume!(volume)
    update_attribute :volume, volume
  end

end
