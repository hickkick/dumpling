class Translator
  def self.t(locale, key, vars = {})
    # Перевірити кеш або звернутися до бази
    value = DB[:translations]
              .where(locale: locale.to_s, key: key)
              .get(:value) ||
            DB[:translations]
              .where(locale: 'uk', key: key)
              .get(:value) ||
            key

    # Підстановка змінних: %{name} тощо
    value % vars rescue value
  end
end