library(tidyverse)
library(readr)
library(ggpubr)
P53_data <- read_csv("TP53_mutations.csv")

p53 <- P53_data %>% 
  select(`Tumor Sample Barcode`, `Variant Classification`) %>% 
  filter(`Variant Classification` != "Silent") %>% 
  separate(`Tumor Sample Barcode`, c("CCL_Name", "Tissue_CCLE"), sep = "_", extra = "merge")

CTRP <- read_tsv(file = "CTRPv2_AUC.txt")
p53_CTRP <- CTRP %>% 
  left_join(., cell_line_info, by= c("CCL_Name" = "Cell_Line_Name")) %>% 
  select(CCL_Name, Tissue, Cellosaurus_Id, cpd_name, Avg_AUC) %>% 
  #need to remove all punctuation
  mutate(CCL_Name = gsub("[[:punct:]]", replacement = "", x = CCL_Name)) %>% 
  left_join(., p53) %>% 
  mutate(p53_mutation = if_else(is.na(`Variant Classification`), "wt", "mut" ))

stat_box_data <- function(y, upper_limit = 20) {
  return( 
    data.frame(
      y = 0.90 * upper_limit,
      label = paste('count =', length(y), '\n',
                    'mean =', round(mean(y), 1), '\n')
    )
  )
}

p53_CTRP %>% 
  select(-`Variant Classification`) %>%
  filter(cpd_name == "MK-1775") %>% 
  unique() %>% 
  ggplot(aes(x= p53_mutation, y = Avg_AUC, color = p53_mutation)) + 
    geom_boxplot() + 
    theme_bw() + 
    stat_compare_means(method = "t.test", label.x = 1.4) + 
    stat_summary(fun.data = stat_box_data, geom = "text", hjust = 0.5, vjust = 0.75) +
    labs(title = "AZD-1775 Sensitivity Stratified by P53 Status in CTRP Cell Lines")

t_test_fun <- function(df){
  t.test(Avg_AUC ~ p53_mutation, data = df)
}

p_val_fun <- function(modl){extract(modl)$p.value}
effect_size_fun <- function(modl){extract(modl)$estimate[2] - extract(modl)$estimate[1]}
  
sig_data <- p53_CTRP %>% 
  select(-`Variant Classification`) %>% 
  unique() %>% 
  group_by(cpd_name) %>% 
  nest() %>% 
  mutate(t_test = map(data, t_test_fun)) %>% 
  mutate(p_value = map_dbl(t_test, p_val_fun)) %>% 
  mutate(wt_minus_mut = map_dbl(t_test, effect_size_fun)) %>% 
  select(cpd_name, p_value, wt_minus_mut) %>% 
  mutate(FDR = p.adjust(p_value, method = "fdr"))

test_stat <- t.test(Avg_AUC ~ p53_mutation, data = test)
extract(test_stat)

write.csv(sig_data, file = "p53_stats_CCL-only.csv")






