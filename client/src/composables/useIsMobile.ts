import { ref } from 'vue';

/**
 * 响应式"小屏/触屏设备"判断(≤768px),与全局 @media 断点保持一致。
 * 用于模板级分支(如移动端隐藏运营 tabs),样式级适配仍走 CSS 媒体查询。
 */
const MOBILE_QUERY = '(max-width: 768px)';

export function useIsMobile() {
  const isMobile = ref(
    typeof window !== 'undefined' && window.matchMedia
      ? window.matchMedia(MOBILE_QUERY).matches
      : false
  );

  if (typeof window !== 'undefined' && window.matchMedia) {
    const mql = window.matchMedia(MOBILE_QUERY);
    const onChange = (e: MediaQueryListEvent) => {
      isMobile.value = e.matches;
    };
    if (mql.addEventListener) {
      mql.addEventListener('change', onChange);
    }
  }

  return { isMobile };
}
