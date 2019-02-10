# radiru-radico-recorder
らじるらじるとラジコを録音します

## 使い方
### NHK らじるらじる用
  rec_nhk_radiru.sh NHKR1|NHKR2|NHKFM 録音時間（分） [出力DIR] [Prefix]
### 民放 Radio 用
  rec_radiko.sh チャンネル名 録音時間（分） [出力ディレクトリ] [Prefix]
どちらも引数なしで起動すると使い方が表示されます。

## インストール
  rec_radiko.sh については、station_xml_dl.rb がシェル変数 BIN_DIR に置かれるようにする必要があります。  

## 参考
  https://memorandum.yamasnet.com/archives/Post-18550.html  
  https://gist.github.com/riocampos/93739197ab7c765d16004cd4164dca73

## Author
  Shimaden
