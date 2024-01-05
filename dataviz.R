
# top 10
tab <- oe %>%
  arrange(-troe) %>%
  head(n = 10) %>%
  select(name, headshot_url, position, plays, plays_made, exp_plays_made, tackle_rate, exp_tackle_rate, troe) %>%
  gt() %>%
  gt_img_rows(columns = headshot_url, height = 50) %>%
  tab_header(
    title = md("Tackle Rate over Expected, Top 10"),
    subtitle = md("2022 season, Weeks 1-9. Minimum 75 snaps on completions")) %>%
  cols_label(
    name = 'Player',
    headshot_url = '',
    position = 'Pos',
    plays = 'Total Plays',
    plays_made = 'Tackles',
    exp_plays_made = 'Exp. Tackles',
    tackle_rate = 'Tackle Rate',
    exp_tackle_rate = 'Exp. Tackle Rate',
    troe = 'TROE'
  ) %>%
  gt_theme_espn() %>%
  gt_color_rows(columns = 'troe', palette = "ggsci::green_material", direction = 1)

gtsave(tab, 'top10.png')

tab

# bottom 10
tab2 <- oe %>%
  filter(!is.na(position)) %>%
  arrange(troe) %>%
  head(n = 10) %>%
  select(name, headshot_url, position, plays, plays_made, exp_plays_made, tackle_rate, exp_tackle_rate, troe) %>%
  gt() %>%
  gt_img_rows(columns = headshot_url, height = 50) %>%
  tab_header(
    title = md("Tackle Rate over Expected, Bottom 10"),
    subtitle = md("2022 season, Weeks 1-9. Minimum 75 snaps on completions")) %>%
  cols_label(
    name = 'Player',
    headshot_url = '',
    position = 'Pos',
    plays = 'Total Plays',
    plays_made = 'Tackles',
    exp_plays_made = 'Exp. Tackles',
    tackle_rate = 'Tackle Rate',
    exp_tackle_rate = 'Exp. Tackle Rate',
    troe = 'TROE'
  ) %>%
  gt_theme_espn() %>%
  gt_color_rows(columns = 'troe', palette = "ggsci::red_material", direction = -1)


gtsave(tab2, 'bottom10.png')
tab2

# scatterplot
oe %>%
  ggplot(aes(x = exp_tackle_rate, y = tackle_rate)) + 
  geom_point(color = oe$team_color,
             fill = oe$team_color2,
             shape = 21,
             stroke = 1) +
  geom_text_repel(aes(label = if_else(abs(tackle_rate - exp_tackle_rate) > 0.0625 | exp_tackle_rate > 0.18, name, ''))) +
  theme_fivethirtyeight() +
  theme(axis.title = element_text(),
        plot.title = element_text(hjust = 0.5),
        plot.subtitle = element_text(hjust = 0.5)) +
  labs(title = 'Expected Tackle Rate vs. Tackle Rate, 2022 Weeks 1-9',
       subtitle = 'Minimum 75 snaps on completions. R = 0.888, R^2 = 0.788',
       x = 'Expected Tackle Rate',
       y = 'Tackle Rate') +
  geom_abline(linetype = 'dashed', color = 'red')

ggsave('corplot.png',width = 11, height = 7)


# feature importance
importance %>%
  select(Feature, Gain) %>% 
  ggplot(aes(x = reorder(Feature, Gain), y = Gain, fill = Gain)) +
  geom_bar(stat = 'identity', linewidth = 1) + 
    scale_fill_gradient(low = "#F97C00", high = "#FE0000") + 
  coord_flip() +
  theme_fivethirtyeight() +
  theme(axis.title = element_text(),
        plot.title = element_text(hjust = 0.5),
        plot.subtitle = element_text(hjust = 0.5),
        axis.text.y = element_text(size = 15),
        legend.position = 'none') +
  labs(title = 'XGBoost Model Feature Importance',
       x = 'Feature',
       y = 'Importance') +
  scale_y_continuous(breaks = scales::pretty_breaks(n = 5))

ggsave('importance.png',width = 11, height = 7)

