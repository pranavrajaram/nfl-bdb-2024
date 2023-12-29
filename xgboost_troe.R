library(tidyverse)
library(nflreadr)
library(gganimate)
library(magick)
library(gifski)
library(randomForest)
library(caret)
library(yardstick)
library(party)
library(partykit)
library(xgboost)
library(ggthemes)
library(gt)
library(gtExtras)
setwd("~/nfl-big-data-bowl-2024")

set.seed(12) # GOAT

track_1 <- read_csv('tracking_week_1.csv')

track_2 <- read_csv('tracking_week_2.csv')

track_3 <- read_csv('tracking_week_3.csv')

track_4 <- read_csv('tracking_week_4.csv')


track_5 <- read_csv('tracking_week_5.csv')

track_6 <- read_csv('tracking_week_6.csv')

track_7 <- read_csv('tracking_week_7.csv')

track_8 <- read_csv('tracking_week_8.csv')

track_9 <- read_csv('tracking_week_9.csv')


all_track <- bind_rows(track_1, track_2, track_3, track_4, track_5, track_6, track_7, track_8, track_9)


games <- read_csv('games.csv')

plays <- read_csv('plays.csv')

players <- read_csv('players.csv')

tackles <- read_csv('tackles.csv') %>%
  replace_na(list(tackle = 0, assist = 0, forcedFumble = 0, pff_missedTackle = 0))

merged_track_1 <- all_track %>% left_join(inner_join(games, plays, by = c('gameId')), by = c("gameId", 'playId')) %>% left_join(tackles, by = c('gameId', 'playId', 'nflId'))

track_with_dist <- merged_track_1 %>%
  group_by(gameId, playId, frameId) %>% 
  mutate(footballInPlay = sum(displayName == "football") > 0) %>% 
  filter(footballInPlay) %>%
  mutate(xFootball = x[displayName == "football"],
         yFootball = y[displayName == "football"]) %>% 
  ungroup() %>%
  group_by(gameId, playId) %>%
  mutate(distToFootball = sqrt((x - xFootball) ^ 2 + (y - yFootball) ^ 2)) %>%
  mutate(distToFootball= as.numeric(distToFootball)) %>%
  replace_na(list(tackle = 0, assist = 0, forcedFumble = 0, pff_missedTackle = 0)) %>%
  ungroup()


defense_dist_at_catch <- track_with_dist %>%
  filter((club != possessionTeam) | (nflId == ballCarrierId)) %>%
  filter(displayName != 'football') %>%
  filter(event == 'pass_outcome_caught') %>%
  mutate(play_made = tackle+assist) %>%
 # mutate(play_made = as.factor(play_made)) %>%
  group_by(gameId, playId, frameId) %>%
  mutate(sBallCarrier = s[nflId == ballCarrierId],
         aBallCarrier = a[nflId == ballCarrierId],
         dirBallCarrier = dir[nflId == ballCarrierId],
         oBallCarrier = o[nflId == ballCarrierId]) %>% 
  filter(club != possessionTeam) %>%
  ungroup()


train_indices <- sample(1:nrow(defense_dist_at_catch), 0.6 * nrow(defense_dist_at_catch))
train_data <- defense_dist_at_catch[train_indices, ]
test_data <- defense_dist_at_catch[-train_indices, ]


dtrain <- xgb.DMatrix(data = as.matrix(train_data[, c('distToFootball', 's', 'a', 'sBallCarrier', 'aBallCarrier', 'dir', 'dirBallCarrier', 'o', 'oBallCarrier')]), label = as.numeric(train_data$play_made))

params <- list(objective = "binary:logistic", max_depth = 3, eta = 0.3, nthread = 2)

xgb_model <- xgboost(data = dtrain, params = params, nrounds = 100)

importance <-  xgb.importance(colnames(dtrain), model = xgb_model)


dtest <- xgb.DMatrix(data = as.matrix(defense_dist_at_catch[, c('distToFootball', 's', 'a', 'sBallCarrier', 'aBallCarrier', 'dir', 'dirBallCarrier', 'o', 'oBallCarrier')]))


predictions <- predict(xgb_model, newdata = dtest)


data_with_preds <- defense_dist_at_catch %>%
  mutate(pred_tackle = as.numeric(predictions),
         play_made = as.numeric(play_made)) %>% arrange(distToFootball) %>%
  arrange(gameId, playId) %>%
  select(nflId, displayName, gameId, playId, quarter, down, playDescription, gameDate, week, play_made, pred_tackle, distToFootball, s, a, sBallCarrier, aBallCarrier)



full_stats <- data_with_preds %>%
  group_by(gameId, playId) %>%
  mutate(highest_prob = max(pred_tackle)) %>% 
  ungroup() %>% 
  mutate(likely_tackler = if_else(pred_tackle < highest_prob, 0, 1)) %>% 
  select(-highest_prob) %>%
  mutate(likely_tackler = as.factor(likely_tackler),
         play_made = as.factor(play_made))

conf_matrix <- confusionMatrix(full_stats$likely_tackler, full_stats$play_made)

tcl <- nflfastR::teams_colors_logos %>%
  select(team_abbr, team_color, team_color2)

rosters <- nflreadr::load_rosters() %>%
  select(gsis_it_id, position, headshot_url, team)

oe <- full_stats %>%
  mutate(likely_tackler = as.numeric(likely_tackler)-1,
         play_made = as.numeric(play_made)-1) %>%
  group_by(nflId) %>%
  summarise(name = first(displayName),
            plays_made = sum(play_made),
            exp_plays_made = sum(likely_tackler),
            plays = n(),
            tackle_rate = plays_made/plays,
            exp_tackle_rate = exp_plays_made/plays,
            troe = tackle_rate - exp_tackle_rate) %>%
  mutate(plays_oe = plays_made - exp_plays_made) %>%
  filter(plays_made != 0 & exp_plays_made != 0) %>%
  ungroup() %>%
  filter(plays >= 60) %>%
  mutate(nflId = as.character(nflId),
         tackle_rate = round(tackle_rate, 3),
         exp_tackle_rate = round(exp_tackle_rate, 3),
         troe = round(troe, 3)) %>%
  left_join(rosters, by = c('nflId' =  'gsis_it_id')) %>%
  left_join(tcl, by = c('team' = 'team_abbr'))


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

full_stats %>%
  mutate(likely_tackler = as.numeric(likely_tackler)-1,
         play_made = as.numeric(play_made)-1) %>%
  mutate(improbability = play_made - pred_tackle) %>% View()


full_stats %>% filter(week == 9) %>% View()
