# app/helpers/application_helper.rb
module ApplicationHelper
  def default_meta_tags
    {
      site: "Eye-meshI（アイめし）",
      title: "Eye-meshI（アイめし） - 栄養を可視化するAI献立提案アプリ",
      description: "栄養バランスを可視化しながら、AIがあなたの毎日の献立を提案",
      canonical: request.original_url,
      og: {
        site_name: "Eye-meshI（アイめし）",
        type: "website",
        image: "#{ENV['RENDER_EXTERNAL_URL'] || 'https://pakuraku-app.onrender.com'}#{asset_path('ogp.png')}"
      },
      twitter: {
        card: "summary_large_image",
        image: "#{ENV['RENDER_EXTERNAL_URL'] || 'https://pakuraku-app.onrender.com'}#{asset_path('ogp.png')}"
      }
    }
  end

  def recipe_meta_tags(calendar_plans)
    menu_text = calendar_plans.map do |plan|
      if meal_plan = JSON.parse(plan.meal_plan, symbolize_names: true)
        "#{plan.date.strftime('%Y年%m月%d日')}の献立\n" \
        "主食：#{meal_plan[:main]}\n" \
        "主菜：#{meal_plan[:side]}\n" \
        "副菜：#{meal_plan[:salad]}"
      end
    end.compact.join("\n\n")

    {
      title: "Eye-meshIで作成した献立",
      description: menu_text,
      og: {
        title: "Eye-meshIで作成した献立",
        description: menu_text,
        image: "#{ENV['RENDER_EXTERNAL_URL'] || 'https://pakuraku-app.onrender.com'}#{asset_path('ogp.png')}"
      },
      twitter: {
        card: "summary_large_image",
        image: "#{ENV['RENDER_EXTERNAL_URL'] || 'https://pakuraku-app.onrender.com'}#{asset_path('ogp.png')}"
      }
    }
  end

  def show_meta_tags
    display_meta_tags(default_meta_tags)
  end
end
