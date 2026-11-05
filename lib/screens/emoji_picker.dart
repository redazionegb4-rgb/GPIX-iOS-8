import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../ui/kit.dart';

const emojiGroups = <String, String>{
  'Per te': '❤️ 🔥 😍 😂 👏 🌈 ✨ 🥰 😘 🫶 💜 🏳️‍🌈 🏳️‍⚧️ 💖 😎 🤍',
  'Smile':
      '😀 😃 😄 😁 😆 😅 😂 🤣 😊 🥹 🙂 🙃 😉 😌 😍 🥰 😘 😗 😙 😚 😋 😛 😝 😜 🤪 🤨 🧐 🤓 😎 🥸 🤩 🥳 😏 😒 😔 😟 😕 🙁 ☹️ 😣 😖 😫 😩 🥺 😢 😭 😤 😠 😡 🤯 😳 🥵 🥶 😱 😨 🤗 🤔 🫣 🤭 🫡 🤫 🤥 😶 😬 🙄 😮 😲 🥱 😴 🤤 😪 😵 🤐 🥴 🤢 🤮 🤧 😷 🤒 🤕',
  'Amore':
      '❤️ 🧡 💛 💚 💙 💜 🖤 🤍 🤎 🩷 🩵 🩶 💔 ❤️‍🔥 ❤️‍🩹 💕 💞 💓 💗 💖 💘 💝 💟 ❣️ 💋 🫶 🤝 🤟 🤙 👏 🙌 👐 🤲 🙏 💪 ✌️ 👍 👎 🥂 💐 🌹',
  'Pride':
      '🌈 🏳️‍🌈 🏳️‍⚧️ ✨ 💜 🦄 🪩 🕺 💃 🫶 👨‍❤️‍👨 👩‍❤️‍👩 👫 👬 👭 🌟 💫 🦋 🌺 🌸 🪷 🔥 🎉 🎊 🥳',
  'Oggetti':
      '☀️ 🌙 ⭐️ 🌧️ ❄️ 🌊 🌴 🌵 🌿 🍀 🌻 🌷 🐶 🐱 🐻 🦊 🐼 🍕 🍔 🍟 🍓 🍒 🍋 ☕️ 🍷 🍸 🍹 🍾 🎂 🎁 🎈 🎧 🎤 🎬 🎨 📸 📍 🏠 🏖️ 🏔️ ✈️ 🚀 💌 🛍️ 💎 👑 🧿',
};

class EmojiPicker extends StatefulWidget {
  final ValueChanged<String> onSelected;
  final String title;
  const EmojiPicker({
    super.key,
    required this.onSelected,
    this.title = 'Emoji e sticker',
  });
  @override
  State<EmojiPicker> createState() => _EmojiPickerState();
}

class _EmojiPickerState extends State<EmojiPicker> {
  String group = 'Per te', query = '';
  final search = TextEditingController();
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final text = query.trim().toLowerCase();
    final groups = text.isEmpty
        ? [group]
        : emojiGroups.keys.where(
            (g) =>
                g.toLowerCase().contains(text) ||
                {
                  'cuore': 'Amore',
                  'amore': 'Amore',
                  'smile': 'Smile',
                  'faccine': 'Smile',
                  'pride': 'Pride',
                  'arcobaleno': 'Pride',
                  'oggetti': 'Oggetti',
                  'sole': 'Oggetti',
                }.entries.any((e) => text.contains(e.key) && e.value == g),
          );
    final emojis = groups
        .expand((g) => emojiGroups[g]!.split(' '))
        .toSet()
        .toList();
    return SizedBox(
      height: MediaQuery.sizeOf(c).height * .62,
      child: Column(
        children: [
          Text(
            widget.title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          const SizedBox(height: 7),
          const Text(
            'Scegli un’emoji',
            style: TextStyle(fontSize: 12, color: muted),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(17, 14, 17, 10),
            child: TextField(
              controller: search,
              onChanged: (v) => setState(() => query = v),
              decoration: InputDecoration(
                hintText: 'Cerca: smile, cuore, pride, oggetti…',
                hintStyle: const TextStyle(fontSize: 12),
                prefixIcon: const GIcon(CupertinoIcons.search, size: 18),
                filled: true,
                fillColor: soft,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              children: [
                for (final g in emojiGroups.keys)
                  Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: ChoiceChip(
                      label: Text(g, style: const TextStyle(fontSize: 11)),
                      selected: group == g,
                      onSelected: (_) => setState(() {
                        group = g;
                        query = '';
                        search.clear();
                      }),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: emojis.isEmpty
                ? const Center(
                    child: Text(
                      'Prova “cuore”, “smile” o “pride”.',
                      style: TextStyle(color: muted),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(15),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 58,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 5,
                        ),
                    itemCount: emojis.length,
                    itemBuilder: (c, i) => InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => widget.onSelected(emojis[i]),
                      child: Center(
                        child: Text(
                          emojis[i],
                          style: const TextStyle(fontSize: 30),
                        ),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
