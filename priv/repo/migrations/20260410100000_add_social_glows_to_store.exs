defmodule Vibeflow.Repo.Migrations.AddSocialGlowsToStore do
  use Ecto.Migration

  def up do
    # Insert Social Glows - Message Skins
    execute """
    INSERT INTO store_items (id, item_name, item_slug, worth, duration, category) VALUES
    (gen_random_uuid(), 'Glassmorphism Pro', 'skin_glassmorphism_pro', 1200, '30 days', 'social_glows'),
    (gen_random_uuid(), 'Matrix Rain', 'skin_matrix_rain', 2500, '30 days', 'social_glows'),
    (gen_random_uuid(), 'Holographic Foil', 'skin_holographic_foil', 3500, '30 days', 'social_glows'),
    (gen_random_uuid(), 'Vantablack', 'skin_vantablack', 5000, '30 days', 'social_glows');
    """
  end

  def down do
    execute """
    DELETE FROM store_items WHERE category = 'social_glows';
    """
  end
end
