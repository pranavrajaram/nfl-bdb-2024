

# data sample
table_ex <- full_stats %>% head(n = 11)

table_ex %>%
  select(displayName, gameId, playId, play_made, pred_tackle, likely_tackler) %>%
  arrange(-pred_tackle) %>%
  gt() %>%
  tab_header(
    title = md("Tackle Probability Model Data Sample"),
    subtitle = md("At Catchpoint")) %>%
  cols_align(align = "center",
             columns = everything()) %>%
  cols_label(
    displayName = 'Player',
    #distToFootball = 'Distance to Football',
    play_made = 'Made Tackle?',
    pred_tackle = 'Tackle Probability',
    likely_tackler = 'Likely Tackler?'
  ) %>%
  gt_theme_espn()

# top 10
tab <- oe %>%
  arrange(-troe) %>%
  head(n = 10) %>%
  select(name, headshot_url, position, plays, plays_made, exp_plays_made, tackle_rate, exp_tackle_rate, troe) %>%
  gt() %>%
  gt_img_rows(columns = headshot_url, height = 50) %>%
  tab_header(
    title = md("Tackle Rate over Expected, Top 10"),
    subtitle = md("2022 season, Weeks 1-9. Minimum 50 snaps on completions")) %>%
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

# bottom 10
tab2 <- oe %>%
  arrange(troe) %>%
  head(n = 10) %>%
  select(name, headshot_url, position, plays, plays_made, exp_plays_made, tackle_rate, exp_tackle_rate, troe) %>%
  gt() %>%
  gt_img_rows(columns = headshot_url, height = 50) %>%
  tab_header(
    title = md("Tackle Rate over Expected, Bottom 10"),
    subtitle = md("2022 season, Weeks 1-9. Minimum 50 snaps on completions")) %>%
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


# scatterplot
oe %>%
  ggplot(aes(x = exp_tackle_rate, y = tackle_rate)) + 
  geom_point(color = oe$team_color,
             fill = oe$team_color2,
             shape = 21,
             stroke = 1) +
  geom_text_repel(aes(label = if_else(abs(tackle_rate - exp_tackle_rate) > 0.07 | exp_tackle_rate > 0.22, name, ''))) +
  theme_fivethirtyeight() +
  theme(axis.title = element_text(),
        plot.title = element_text(hjust = 0.5),
        plot.subtitle = element_text(hjust = 0.5)) +
  labs(title = 'Expected Tackle Rate vs. Tackle Rate, 2022 Weeks 1-9',
       subtitle = 'Minimum 50 snaps on completions. R = 0.864, R^2 = 0.747',
       x = 'Expected Tackle Rate',
       y = 'Tackle Rate') +
  geom_abline(linetype = 'dashed', color = 'red')

ggsave('corplot.png',width = 11, height = 7)


importance %>%
  select(Feature, Gain) %>% 
  ggplot(aes(x = reorder(Feature, Gain), y = Gain)) +
  geom_bar(stat = 'identity', color = 'darkred', fill = 'gray', size = 2) + 
  coord_flip() +
  theme_fivethirtyeight() +
  theme(axis.title = element_text(),
        plot.title = element_text(hjust = 0.5),
        plot.subtitle = element_text(hjust = 0.5)) +
  labs(title = 'XGBoost Model Feature Importance',
       x = 'Feature',
       y = 'Importance')

ggsave('importance.png',width = 11, height = 7)

